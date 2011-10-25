/******************************************************************************
*******************************************************************************
*******************************************************************************


    kernel-filesystem-monitor-daemon
    Copyright (C) 2005 Ben Martin

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    For more details see the COPYING file in the root directory of this
    distribution.

    $Id: kernel-filesystem-monitor-daemon.cpp,v 1.4 2008/05/25 21:30:52 ben Exp $

*******************************************************************************
*******************************************************************************
******************************************************************************/

#include <sys/types.h>
#include <unistd.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <dirent.h>
#include <sys/poll.h>
#include <signal.h>
#include <string.h>
#include <errno.h>
#include <syslog.h>
#include <stdlib.h>
#include <limits.h>

#include <sys/inotify.h>
//#include "inotify-syscalls.h"

#include <iostream>
#include <sstream>

#include <kernel-filesystem-monitor-daemon.hh>

static bool WantToQuit = false;
unsigned long Verbose = 0;

//#ifdef IN_CREATE_SUBDIR
//#define MY_CREATE_SUBDIR_MASK IN_CREATE_SUBDIR | IN_CREATE_FILE
//#else
#define MY_CREATE_SUBDIR_MASK IN_CREATE
//#endif

static void sig_term_cb(int sign)
{
    syslog( LOG_INFO, "preparing to exit... pid:%d", getpid() );
    WantToQuit = true;
}

static void sig_usr1_cb(int sign)
{
    sig_term_cb(sign);
}

static void sig_usr2_cb(int sign)
{
    /* ping */
    if( Verbose )
    {
        syslog( LOG_INFO, "got a ping! pid:%d", getpid() );
    }
}

struct  tolowerstr : public std::unary_function< std::string , std::string >
{
    /**
     */
    inline std::string operator()(const std::string& x) const
        {
            std::string ret = x;
                
            for( std::string::iterator p = ret.begin(); p != ret.end(); ++p )
            {
                *p = ::tolower( *p );
            }
                
            return ret;
        }
};

static bool  starts_with( const string& s, const string& starting )
{
    int starting_len = starting.length();
    int s_len = s.length();

    if( s_len < starting_len )
        return false;
    
    return !s.compare( 0, starting_len, starting );
}

string getHomeDir( const char* homedir_CSTR )
{
    if( homedir_CSTR )
        return homedir_CSTR;
    if( const char* en = getenv( "HOME" ) )
        return en;
    return "";
//    cerr << "Can not work out your home directory! use the --homedir argument\n";
//    exit(1);
}



/********************************************************************************/
/********************************************************************************/
/********************************************************************************/

KernelFileSystemMonitorDaemon::KernelFileSystemMonitorDaemon()
    :
    m_runInForground( 0 ),
    watch_mask( IN_ATTRIB |
                IN_MOVED_FROM |
                IN_MOVED_TO |
                MY_CREATE_SUBDIR_MASK |

#ifdef IN_DELETE_FILE
                IN_DELETE_FILE |
#endif
#ifdef IN_DELETE
                IN_DELETE |
#endif
                IN_CLOSE_WRITE 
        ),
    dev_fd( 0 ),
    m_inotify_queue_threshold_bytes( 8 * 1024 ),
    m_nanosleep_ns( 50 * 1000 * 1000 ),
    m_inotify_queue_sleep_threshold_ns( 200 * 1000 * 1000 )
{
//    watch_mask = IN_ALL_EVENTS;
}
KernelFileSystemMonitorDaemon::~KernelFileSystemMonitorDaemon()
{
}


void
KernelFileSystemMonitorDaemon::background_into_daemon()
{
    pid_t pid = 0;

    if((pid = fork()) < 0 )
    {
        syslog( LOG_EMERG, "can't fork()", 0 );
        exit( 1 );
    }
    else if( pid != 0 )
        exit(0);

    setsid();
    chdir("/");
    umask(0);
}


void
KernelFileSystemMonitorDaemon::priv_handle_event( struct inotify_event *pevent, time_t tt )
{
    handle_event( pevent, tt );
}

void
KernelFileSystemMonitorDaemon::event_batch_start( time_t tt )
{
}

void
KernelFileSystemMonitorDaemon::event_batch_end( time_t tt )
{
}


void
KernelFileSystemMonitorDaemon::setupSignalHandlers()
{
    struct sigaction newinth;
    newinth.sa_handler = sig_term_cb;
    sigemptyset(&newinth.sa_mask);
    newinth.sa_flags   = SA_RESTART;
    if( -1 == sigaction( SIGTERM, &newinth, NULL))
    {
        syslog( LOG_ERR, "ERROR: can not setup signal handling. reason:%s", strerror(errno) );
        exit(2);
    }
    if( -1 == sigaction( SIGQUIT, &newinth, NULL))
    {
        syslog( LOG_ERR, "ERROR: can not setup signal handling. reason:%s", strerror(errno) );
        exit(2);
    }

    newinth.sa_handler = sig_usr1_cb;
    sigemptyset(&newinth.sa_mask);
    newinth.sa_flags   = SA_RESTART;
    if( -1 == sigaction( SIGUSR1, &newinth, NULL))
    {
        syslog( LOG_ERR, "ERROR: can not setup signal handling. reason:%s", strerror(errno) );
        exit(2);
    }

    newinth.sa_handler = sig_usr2_cb;
    sigemptyset(&newinth.sa_mask);
    newinth.sa_flags   = SA_RESTART;
    if( -1 == sigaction( SIGUSR2, &newinth, NULL))
    {
        syslog( LOG_ERR, "ERROR: can not setup signal handling. reason:%s", strerror(errno) );
        exit(2);
    }
}

void
KernelFileSystemMonitorDaemon::priv_Closedown()
{
    Closedown();
}

void
KernelFileSystemMonitorDaemon::print_event (struct inotify_event *event)
{
    if( m_runInForground )
    {
	if (event->len)
	{
		cout << "M " << m_workingDirToURL[event->wd] << "/" << event->name << endl;
		// cout << "-" << endl;
	}
	#if 0
        cout << "event on wd:" << event->wd << " " << m_workingDirToURL[event->wd];
        if (event->len)
        {
            cout << " filename:" << event->name;
        }
        cout << endl;
        print_mask( cout, event->mask );
        if (event->len)
        {
            cout << " URL:" << m_workingDirToURL[event->wd] << "/" << event->name
                 << endl;
        }
	#endif
    }
    else
    {
        stringstream maskss;
        print_mask( maskss, event->mask );
        syslog( LOG_DEBUG, "event on wd:%s mask:%s file:%s\n",
                m_workingDirToURL[event->wd].c_str(),
                maskss.str().c_str(),
                event->name );
    }
}


bool
KernelFileSystemMonitorDaemon::shouldAddSubObject( int wd, const std::string& fn )
{
    struct stat statbuf;
    
    if( fn == "." || fn == ".." )
        return false;
    
    int rc = lstat( fn.c_str(), &statbuf );
    if( !rc )
    {
        candidateObject( wd, fn, statbuf );
        if( S_ISDIR( statbuf.st_mode) )
        {
            return true;
        }
    }
    return false;
}

void
KernelFileSystemMonitorDaemon::candidateObject( int wd, const std::string& fn, struct stat& statbuf )
{
}



void
KernelFileSystemMonitorDaemon::Closedown()
{
}


void
KernelFileSystemMonitorDaemon::setRunInForground( bool v )
{
    m_runInForground = v;
}


bool
KernelFileSystemMonitorDaemon::shouldWatch( const string& earl )
{
    for( m_ignorePrefixes_t::iterator ci = m_ignorePrefixes.begin();
         ci != m_ignorePrefixes.end(); ++ci )
    {
        if( starts_with( earl, *ci ) )
            return false;
    }
    
    return true;
}

bool
KernelFileSystemMonitorDaemon::handle_create_subdir_event_by_maybe_watching(
    struct inotify_event *pevent, time_t tt )
{
//     cerr << "pevent->mask:" << hex << pevent->mask
//          << " MY_CREATE_SUBDIR_MASK:" << hex << MY_CREATE_SUBDIR_MASK
//          << dec
//          << endl;
    
    if ( pevent->mask & MY_CREATE_SUBDIR_MASK )
    {
        string dirName = m_workingDirToURL[ pevent->wd ];
        chdir( dirName.c_str() );
//        cerr << "have dirname:" << dirName << endl;
        
        if( shouldAddSubObject( pevent->wd, pevent->name ) )
        {
            string earl = dirName + "/" + pevent->name;
            m_watchRoots.push_back( earl );
            return true;
        }
    }
    return false;
}




void
KernelFileSystemMonitorDaemon::add_watches_recursive( const string& earl )
{
    if( !shouldWatch( earl ) )
        return;
    
//    struct inotify_watch_request req;
    
    int fd = open ( earl.c_str(), O_RDONLY);
    
    if (fd < 0)
    {
        syslog( LOG_WARNING, "not monitoring:%s reason:%s", earl.c_str(), strerror(errno));
        return;
    }

    fchdir(fd);
//     req.fd = fd;
//     req.mask = IN_CREATE_SUBDIR;
//    long wd = ioctl( dev_fd, INOTIFY_WATCH, &req );
    long wd = inotify_add_watch( dev_fd, earl.c_str(), MY_CREATE_SUBDIR_MASK );
    m_workingDirToURL[ wd ] = earl;
    setupWorkingDirToPersistentDirIDMapping( wd, earl );
    
    //
    // Gather up the subdirectory names into dirNames
    //
    typedef list< string > dirNames_t;
    dirNames_t dirNames;
    
    DIR *d;
    struct dirent *e;
    if ((d = opendir (earl.c_str())) == NULL)
    {
        syslog( LOG_WARNING, "not monitoring:%s reason:%s", earl.c_str(), strerror(errno));
    }
    else
    {
        while( e = readdir(d) )
        {
            if( shouldAddSubObject( wd, e->d_name ) )
            {
                dirNames.push_back( e->d_name );
                if( Verbose )
                    cerr << "might add monitor for:" << e->d_name << endl;
            }
        }
        closedir (d);
    }

    //
    // Check to see if a new directory was created while
    // we were readdir()ing
    //
    {
//        cerr << "***** BEGIN ******  checking bg info url:" << earl << endl;
        
        const int buf_sz = 16 * 1024;
        char buf[ buf_sz + 1 ];
        int event_count = 0;

        unsigned int nfds = 1;
        struct pollfd ufds;
        ufds.fd = dev_fd;
        ufds.events  = POLLIN;
        ufds.revents = 0;

        int poll_rc = poll( &ufds, nfds, 0 );
        for( ; poll_rc ; poll_rc = poll( &ufds, nfds, 0 ) )
            {
                size_t len = read( dev_fd, buf, buf_sz);
                if( !len )
                    break;
                
                size_t buf_iter = 0;

//                 cerr << "buf_iter:" << buf_iter << " len:" << len << endl;
//                 cerr << "dev_fd:" << dev_fd << endl;
            
                while (buf_iter < len)
                {
                    /* Parse events and queue them ! */
                    struct inotify_event * pevent
                        = (struct inotify_event *)&buf[buf_iter];

                    handle_create_subdir_event_by_maybe_watching( pevent, 0 );

                    int event_size = sizeof(struct inotify_event) + pevent->len;
                    buf_iter += event_size;
                    event_count++;
                }
            }
//        cerr << "***** END ******  checking bg info url:" << earl << endl;
    }

    //
    // switch to monitoring all interesting things for this directory.
    //
//     req.fd = fd;
//     req.mask = watch_mask;
//     wd = ioctl( dev_fd, INOTIFY_WATCH, &req );
    wd = inotify_add_watch( dev_fd, earl.c_str(), watch_mask );
    close (fd);
    
    //
    // Monitor the subdirectories
    //
    for( dirNames_t::const_iterator di = dirNames.begin();
         di != dirNames.end(); ++di )
    {
        add_watches_recursive( earl + "/" + *di );
    }
    
}

void
KernelFileSystemMonitorDaemon::addIgnorePrefix( const string& s )
{
    m_ignorePrefixes.push_back( s );
}

void
KernelFileSystemMonitorDaemon::ParseWatchOptions( poptContext& optCon )
{
    string opcode = "";
    while( const char* tmpCSTR = poptGetArg(optCon) )
    {
        string s = tmpCSTR;
        string ls = tolowerstr()(s);

//        cerr << " s:" << s << endl;
        
        if( ls == "ignorepfx" )
        {
            opcode = ls;
            continue;
        }
        if( ls == "watch" )
        {
            opcode = ls;
            continue;
        }
        
        if( opcode == "ignorepfx" )
        {
            m_ignorePrefixes.push_back( s );
        }
        else if( opcode == "watch" )
        {
            if( Verbose )
                cerr << "setting up watch for:" << s << endl;
            m_watchRoots.push_back( s );
        }
    }
    
}


void
KernelFileSystemMonitorDaemon::setupWatches()
{
    if( !dev_fd )
    {
//        dev_fd = open ("/dev/inotify", O_RDONLY);
        dev_fd = inotify_init();
        if( dev_fd < 0 )
        {
            syslog( LOG_ERR, "Exiting due to failure to open inotify device reason:%s", strerror(errno));
            cerr << "Exiting due to failure to open /dev/inotify device reason:" <<  strerror(errno)
                 << endl;
            exit( 1 );
        }
    }

    if( m_watchRoots.empty() )
    {
        cerr << "No directories/files to watch have been specified!" << endl;
    }
    else
    {
        for( stringlist_t::const_iterator ci = m_watchRoots.begin();
             ci != m_watchRoots.end(); ++ci )
        {
            add_watches_recursive( *ci );
        }
    }
}

void
KernelFileSystemMonitorDaemon::HandleSleepForQueueSize()
{
    unsigned long long time_slept = 0;

    while( !WantToQuit )
    {
        unsigned int bytesAvailable = 0;
        int iorc = ioctl( dev_fd, FIONREAD, &bytesAvailable, 0 );
        if( iorc < 0 )
        {
            // error
        }

        syslog( LOG_DEBUG,
                "HandleQ() bytesAvailable:%d iorc:%d "
                "queue_threshold_bytes:%d "
                "queue_sleep_threshold_ns:%d time_slept:%d",
                bytesAvailable, iorc, 
                m_inotify_queue_threshold_bytes,
                m_inotify_queue_sleep_threshold_ns,
                time_slept );
//         cerr << "HandleQ() bytesAvailable:" << bytesAvailable
//              << " iorc:" << iorc
//              << " queue_threshold_bytes:" << m_inotify_queue_threshold_bytes
//              << " queue_sleep_threshold_ns:" << m_inotify_queue_sleep_threshold_ns
//              << " time_slept:" << time_slept
//              << endl;

        if( time_slept >= m_inotify_queue_sleep_threshold_ns )
        {
            if( !bytesAvailable )
            {
                time_slept = 0;

                unsigned int nfds = 1;
                struct pollfd ufds;
                ufds.fd = dev_fd;
                ufds.events  = POLLIN;
                ufds.revents = 0;

                // if the system is idle we should really switch to
                // poll() here so that we are not a burden
                int poll_rc = poll( &ufds, nfds, -1 );
                syslog( LOG_DEBUG, "after poll() rc:%d", poll_rc );

                continue;
            }
            
            return;
        }

        if( bytesAvailable >= m_inotify_queue_threshold_bytes )
        {
            return;
        }

        //
        // Time to go for a little kip
        //
        struct timespec nts;
        nts.tv_sec = 0;
        nts.tv_nsec = m_nanosleep_ns;
        struct timespec rem;
        bzero( &rem, sizeof(rem) );
                
        while( nanosleep( &nts, &rem ) < 0 )
        {
            if( WantToQuit )
                return;
            
            if( errno == EINTR )
            {
                nts = rem;
                bzero( &rem, sizeof(rem) );
                continue;
            }
            else
            {
                // error
                break;
            }
        }
        time_slept += m_nanosleep_ns;
        continue;
    }
}


int
KernelFileSystemMonitorDaemon::run()
{
//    cerr << "KernelFileSystemMonitorDaemon::run() starting" << endl;
    
    chdir("/");

    const int buf_sz = 32 * 1024;
    char buf[ buf_sz + 1 ];
    int event_count = 0;
    
    while( true )
    {
        HandleSleepForQueueSize();
        syslog( LOG_DEBUG, "After HandleSleepForQueueSize()", 0 );

        if( WantToQuit )
        {
            Closedown();
            return 0;
        }
        
        if( size_t len = read( dev_fd, buf, buf_sz) )
        {
            if( len > SSIZE_MAX )
                continue;

            time_t tt = time( 0 );
                
            size_t buf_iter = 0;
            bool have_new_subdirs_to_watch = false;

//                 cerr << "buf_iter:" << buf_iter << " len:" << len << endl;
//                 cerr << "dev_fd:" << dev_fd << endl;

            event_batch_start( tt );
            
            while (buf_iter < len)
            {
                /* Parse events and queue them ! */
                struct inotify_event * pevent
                    = (struct inotify_event *)&buf[buf_iter];

                have_new_subdirs_to_watch |= 
                    handle_create_subdir_event_by_maybe_watching( pevent, tt );
                handle_event( pevent, tt );

                int event_size = sizeof(struct inotify_event) + pevent->len;
                buf_iter += event_size;
                event_count++;
            }

            event_batch_end( tt );
		
		cout << "-" << endl;

            if( have_new_subdirs_to_watch )
                setupWatches();
        }
    }

//    cerr << "KernelFileSystemMonitorDaemon::run() exiting" << endl;
    return 0;
        
}


struct ::poptOption*
KernelFileSystemMonitorDaemon::getPopTable()
{
    static struct poptOption optionsTable[] =
        {
            { "inotify-queue-threshold-bytes", 0, POPT_ARG_INT, &m_inotify_queue_threshold_bytes, 0,
              "number of bytes that should be available on /dev/inotify before reading", "" },

            { "inotify-queue-sleep-threshold-ns", 0, POPT_ARG_INT, &m_inotify_queue_sleep_threshold_ns, 0,
              "after this time read the inotify queue anyway", "" },

            { "inotify-sleep-delay-ns", 0, POPT_ARG_INT, &m_nanosleep_ns, 0,
              "nanoseconds to sleep if /dev/inotify is not full enough", "" },
            
            POPT_TABLEEND
        };
    return optionsTable;
}













