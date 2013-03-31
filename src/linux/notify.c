#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/inotify.h>
#include <unistd.h>
#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/ioctl.h>

/* gcc should be able to optimize strlen() for constant strings */
#define PRINT(str) write(1, str, strlen(str))
#define ERROR(str) write(2, str, strlen(str))

#define EVENT_MASK (IN_CLOSE_WRITE|IN_CREATE|IN_DELETE|IN_DELETE_SELF|IN_MODIFY|IN_MOVE_SELF\
    |IN_MOVED_FROM|IN_MOVED_TO|IN_DONT_FOLLOW|IN_ONLYDIR|IN_ATTRIB)

#ifdef DEBUG
#define DEBUG_PRINT printf
#else
#define DEBUG_PRINT(...) /* printf actually adds about 7k to binary size :) */
#endif

typedef struct {
    int wd;
    int parent_wd;
    char *name;
} _watchstruct;

char events_buf[PATH_MAX + sizeof(struct inotify_event) + 1];
static _watchstruct *watches;
int ifd = 0, max_watches;
char *watch_dir;

/* make directory path for watch descriptor (recursively) */
static void wd_path(int wd, char *path)
{
    if (wd == 0) {
        strcpy(path, watch_dir);
        strcat(path, "/");
        return;
    }

    if (wd < 0 || !watches[wd].name) {
        DEBUG_PRINT("Recusive %d, %x\n", wd, watches[wd].name);
        ERROR("Memory corrupted: asked path of deleted event\n");
        exit(1);
    }

    wd_path(watches[wd].parent_wd, path);
    if (watches[wd].name[0] == 0) return;

    strcat(path, watches[wd].name);
    strcat(path, "/");
}

static int add_dir_watch(int parent_wd, char *dir, char *dir_name, int no_print)
{
    int wd = inotify_add_watch(ifd, dir, EVENT_MASK);
    if (wd < 0) {
        ERROR("Cannot add watch to '");
        ERROR(dir);
        ERROR("' using inotify: ");
        if (errno == ENOSPC) {
            ERROR("too many watches\nYou can increase number of user watches using /proc/sys/fs/inotify/max_user_watches");
        } else {
            ERROR(strerror(errno));
        }
        ERROR("\n");
        if (errno != EACCES && errno != ENOENT) exit(1);
        return wd;
    }

    if (wd >= max_watches) {
        ERROR("\nToo many events; restart required to prevent watch descriptor overflow.\n");
        exit(3);
    }

    dir_name = strdup(dir_name);
    if (!dir_name) {
        ERROR("Cannot strdup(dir_name)\n");
        exit(1);
    }

    watches[wd].wd = wd;
    watches[wd].parent_wd = parent_wd;
    if (watches[wd].name) free(watches[wd].name);
    watches[wd].name = dir_name;

    if (!no_print) {
        PRINT("M ");
        PRINT(dir);
        PRINT("\n");
    }

    return wd;
}

static void add_dir(int dir_wd, char *dir, int errors_fatal, int no_print)
{
    char path[PATH_MAX + 1];
    DIR *dh = opendir(dir);
    struct dirent *ent;
    struct stat st;
    int dirl = strlen(dir), n = sizeof(path) - 1 - dirl, had_errors = 0, wd;

    if (dirl > sizeof(path) - 3) {
        ERROR("Too long path (not watched): ");
        ERROR(dir);
        ERROR("\n");

        if (errors_fatal) exit(1);
        return;
    }

    if (!dh) {
        ERROR("Cannot opendir(");
        ERROR(dir);
        ERROR("): ");
        ERROR(strerror(errno));
        ERROR("\n");

        if (errors_fatal) exit(1);
        return;
    }

    strcpy(path, dir);

    while ((ent = readdir(dh)) != NULL) {
        if (!strcmp(ent->d_name, ".") || !strcmp(ent->d_name, "..") || !strcmp(ent->d_name, ".unrealsync")) continue;

        path[dirl] = '/';
        path[dirl + 1] = 0;
        strncat(path + dirl, ent->d_name, n);
        path[sizeof(path) - 1] = 0;
        if (lstat(path, &st)) {
            ERROR("Cannot lstat(");
            ERROR(path);
            ERROR("): ");
            ERROR(strerror(errno));
            ERROR("\n");
            had_errors = 1;
            continue;
        }

        if (S_ISDIR(st.st_mode)) {
            wd = add_dir_watch(dir_wd, path, ent->d_name, no_print);
            if (wd < 0) continue;
            add_dir(wd, path, errors_fatal, no_print);
        }
    }

    closedir(dh);

    if (errors_fatal && had_errors) exit(1);
}

void debug_print_mask(uint32_t mask)
{
    if (mask & IN_DELETE_SELF) DEBUG_PRINT("IN_DELETE_SELF ");
    if (mask & IN_MOVE_SELF)   DEBUG_PRINT("IN_MOVE_SELF ");
    if (mask & IN_MOVED_FROM)  DEBUG_PRINT("IN_MOVED_FROM ");
    if (mask & IN_MOVED_TO)    DEBUG_PRINT("IN_MOVED_TO ");
    if (mask & IN_CLOSE_WRITE) DEBUG_PRINT("IN_CLOSE_WRITE ");
    if (mask & IN_MODIFY)      DEBUG_PRINT("IN_MODIFY ");
    if (mask & IN_IGNORED)     DEBUG_PRINT("IN_IGNORED ");
    if (mask & IN_ISDIR)       DEBUG_PRINT("IN_ISDIR ");
    if (mask & IN_Q_OVERFLOW)  DEBUG_PRINT("IN_Q_OVERFLOW ");
    if (mask & IN_UNMOUNT)     DEBUG_PRINT("IN_UNMOUNT ");
    if (mask & IN_CREATE)      DEBUG_PRINT("IN_CREATE ");
}

static int do_watch(int max_watches)
{
    struct inotify_event *ev = (struct inotify_event*)events_buf;
    ssize_t n = 0, wd;
    char path[PATH_MAX + 1];

    watches = (_watchstruct*) calloc(max_watches, sizeof(_watchstruct));
    if (!watches) {
        ERROR("Cannot allocate memory\n");
        exit(1);
    }

    DEBUG_PRINT("Doing initial watches setup\n");

    ifd = inotify_init();
    if (ifd == -1) {
        perror("Cannot init inotify");
        exit(1);
    }

    wd = add_dir_watch(0, watch_dir, "", 1);
    if (wd < 0) {
        ERROR("Cannot add dir watch\n");
        exit(1);
    }
    add_dir(wd, watch_dir, 1, 1);

    while ((n = read(ifd, events_buf, sizeof(events_buf))) > 0) {
        ev = (struct inotify_event*)events_buf;
        while (n > 0) {
            if (ev->mask & IN_Q_OVERFLOW) {
                ERROR("Queue overflow, restart needed\n");
                exit(3);
            }

            if (ev->mask & IN_IGNORED) {
                free(watches[ev->wd].name);
                watches[ev->wd].parent_wd = -1;
                watches[ev->wd].name = NULL;
                goto loop_end;
            }

            wd_path(ev->wd, path);
            PRINT("M ");
            PRINT(path);
            PRINT("\n");
            #ifdef DEBUG
            if (ev->len) {
                DEBUG_PRINT(" | ");
                DEBUG_PRINT("%s", ev->name);
            }
            DEBUG_PRINT(" | ");
            debug_print_mask(ev->mask);
            #endif

            if ((ev->mask & IN_DELETE) || (ev->mask & IN_MOVED_FROM)) {
                goto loop_end;
            }

            if (ev->mask & IN_ISDIR) {
                if (ev->len + strlen(path) > sizeof(path) - 1) {
                    ERROR("Too deep directory: ");
                    ERROR(path);
                    ERROR(ev->name);
                    ERROR("\n");
                    goto loop_end;
                }
                strcat(path, ev->name);
                wd = add_dir_watch(ev->wd, path, ev->name, 0);
                if (wd < 0) goto loop_end;
                add_dir(ev->wd, path, 0, 0);
            }

            loop_end:
            n -= sizeof(struct inotify_event) + ev->len;
            ev = (struct inotify_event*) ((char*)ev + sizeof(struct inotify_event) + ev->len);
        }

        PRINT("-\n");
    }

    perror("Cannot read() inotify queue");
    exit(1);
}

int main(int argc, char *argv[])
{
    int fd, n;
    char buf[12];

    if (argc != 2) {
        ERROR("Usage: notify <dir>\n");
        return 1;
    }

    fd = open("/proc/sys/fs/inotify/max_user_watches", O_RDONLY);
    if (fd < 0) {
        perror("Cannot open /proc/sys/fs/inotify/max_user_watches");
        return 1;
    }

    if ( (n = read(fd, buf, sizeof(buf) - 1)) < 0) {
        perror("Cannot read() /proc/sys/fs/inotify/max_user_watches");
        return 1;
    }

    buf[n] = 0;
    max_watches = atoi(buf) * 2;
    if (max_watches <= 0) {
        ERROR("Incorrect number of watches: ");
        ERROR(buf);
        ERROR("\n");
        return 1;
    } else {
        DEBUG_PRINT("Max watches: %d\n", max_watches);
    }

    watch_dir = argv[1];
    do_watch(max_watches);

    return 0;
}
