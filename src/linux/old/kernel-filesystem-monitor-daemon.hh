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

    $Id: kernel-filesystem-monitor-daemon.hh,v 1.3 2008/01/03 21:31:06 ben Exp $

*******************************************************************************
*******************************************************************************
******************************************************************************/

#ifndef _ALREADY_INCLUDED_KERNEL_FILESYSTEM_MONITOR_DAEMON_HH_
#define _ALREADY_INCLUDED_KERNEL_FILESYSTEM_MONITOR_DAEMON_HH_

#include <sys/stat.h>

#include <sys/inotify.h>
#include <popt.h>

#include <string>
#include <map>
#include <set>
#include <list>

using namespace std;

extern unsigned long Verbose;

string getHomeDir( const char* homedir_CSTR );

/********************************************************************************/
/********************************************************************************/
/********************************************************************************/

template< class STREAM >
void print_mask(STREAM& ss,int mask)
{
    if (mask & IN_ACCESS)
    {
        ss << "ACCESS ";
    }
    if (mask & IN_MODIFY)
    {
        ss << "MODIFY ";
    }
    if (mask & IN_ATTRIB)
    {
        ss << "ATTRIB ";
    }
    if (mask & IN_CLOSE)
    {
        ss << "CLOSE ";
    }
    if (mask & IN_OPEN)
    {
        ss << "OPEN ";
    }
    if (mask & IN_MOVED_FROM)
    {
        ss << "MOVE_FROM ";
    }
    if (mask & IN_MOVED_TO)
    {
        ss << "MOVE_TO ";
    }
#ifdef IN_DELETE_SUBDIR
    if (mask & IN_DELETE_SUBDIR)
    {
        ss << "DELETE_SUBDIR ";
    }
#endif
#ifdef IN_DELETE
    if (mask & IN_DELETE)
    {
        ss << "DELETE ";
    }
#endif
#ifdef IN_DELETE_FILE
    if (mask & IN_DELETE_FILE)
    {
        ss << "DELETE_FILE ";
    }
#endif
#ifdef IN_DELETE_SELF
    if (mask & IN_DELETE_SELF)
    {
        ss << "DELETE_SELF ";
    }
#endif
#ifdef IN_CREATE_SUBDIR
    if (mask & IN_CREATE_SUBDIR)
    {
        ss << "CREATE_SUBDIR ";
    }
#endif
#ifdef IN_CREATE_FILE
    if (mask & IN_CREATE_FILE)
    {
        ss << "CREATE_FILE ";
    }
#endif
#ifdef IN_CREATE
    if (mask & IN_CREATE)
    {
        ss << "CREATE ";
    }
#endif
    if (mask & IN_DELETE_SELF)
    {
        ss << "DELETE_SELF ";
    }
    if (mask & IN_UNMOUNT)
    {
        ss << "UNMOUNT ";
    }
    if (mask & IN_Q_OVERFLOW)
    {
        ss << "Q_OVERFLOW ";
    }
    if (mask & IN_IGNORED)
    {
        ss << "IGNORED" ;
    }
}

/********************************************************************************/
/********************************************************************************/
/********************************************************************************/

class KernelFileSystemMonitorDaemon
{
    bool m_runInForground;

#define ALL_MASK 0xffffffff
    int watch_mask;
    int dev_fd;

    unsigned long m_inotify_queue_threshold_bytes;
    unsigned long long m_inotify_queue_sleep_threshold_ns;
    unsigned long m_nanosleep_ns;

    void background_into_daemon();
    
    void priv_handle_event( struct inotify_event *pevent, time_t tt );
    void priv_Closedown();

    bool handle_create_subdir_event_by_maybe_watching( struct inotify_event *pevent, time_t tt );

    void HandleSleepForQueueSize();
    
protected:
    typedef map< int, string > m_workingDirToURL_t;
    m_workingDirToURL_t m_workingDirToURL;

    typedef list< string > m_ignorePrefixes_t;
    m_ignorePrefixes_t m_ignorePrefixes;

    typedef list< string > stringlist_t;
    stringlist_t m_watchRoots;
    
    void print_event (struct inotify_event *event);
    
    bool shouldAddSubObject( int wd, const std::string& fn );
    virtual void candidateObject( int wd, const std::string& fn, struct stat& statbuf );
    virtual void setupWorkingDirToPersistentDirIDMapping( long wd, const string& earl ) = 0;
    virtual void event_batch_start( time_t tt );
    virtual void event_batch_end( time_t tt );
    virtual void handle_event( struct inotify_event *pevent, time_t tt ) = 0;
    virtual void Closedown();

public:
    KernelFileSystemMonitorDaemon();
    ~KernelFileSystemMonitorDaemon();

    void setRunInForground( bool v );

    void setupWatches();
    void setupSignalHandlers();
    bool shouldWatch( const string& earl );
    void add_watches_recursive( const string& earl );

    void addIgnorePrefix( const string& s );
    void ParseWatchOptions( poptContext& optCon );

    int run();


    struct ::poptOption* getPopTable();
    
};

#endif
