/******************************************************************************
*******************************************************************************
*******************************************************************************


    kernel-filesystem-monitor-daemon-cat
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

    $Id: kernel-filesystem-monitor-daemon-cat.cpp,v 1.3 2008/05/25 21:30:52 ben Exp $

*******************************************************************************
*******************************************************************************
******************************************************************************/

#include <iostream>
#include "kernel-filesystem-monitor-daemon.hh"
#include <stdlib.h>

using namespace std;


const char* PROGRAM_NAME = "kernel-filesystem-monitor-cat";

void usage(poptContext optCon, int exitcode, char *error, char *addl)
{
    poptPrintUsage(optCon, stderr, 0);
    if (error) fprintf(stderr, "%s: %s0", error, addl);
    exit(exitcode);
}

/********************************************************************************/
/********************************************************************************/
/********************************************************************************/
/********************************************************************************/
/********************************************************************************/
/********************************************************************************/



class KernelFileSystemMonitorDaemonCat
    :
    public KernelFileSystemMonitorDaemon
{
protected:

    virtual void handle_event( struct inotify_event *pevent, time_t tt );
    virtual void Closedown();
    virtual void setupWorkingDirToPersistentDirIDMapping( long wd, const string& earl );

    void
    event_batch_start( time_t tt )
        {}
    
    void
    event_batch_end( time_t tt )
        {}


public:

    string homedir;
    
    KernelFileSystemMonitorDaemonCat()
        {}
};


void
KernelFileSystemMonitorDaemonCat::setupWorkingDirToPersistentDirIDMapping(
    long wd, const string& earl )
{
}

void
KernelFileSystemMonitorDaemonCat::handle_event( struct inotify_event *pevent, time_t tt )
{
    print_event( pevent );
    fflush(stdout);
}



void
KernelFileSystemMonitorDaemonCat::Closedown()
{
}

int main( int argc, char** argv )
{
    unsigned long RunInForground = 0;
    const char* homedir_CSTR     = 0;

    KernelFileSystemMonitorDaemonCat* daemon
        = new KernelFileSystemMonitorDaemonCat();
    
    struct poptOption optionsTable[] =
        {
            { "forground", 'F', POPT_ARG_NONE, &RunInForground, 0,
              "Don't run the daemon in the background", "" },

            { "homedir", 'H', POPT_ARG_STRING, &homedir_CSTR, 0,
              "Home directory for user doing the monitoring", "" },

            { 0, 0, POPT_ARG_INCLUDE_TABLE, daemon->getPopTable(), \
              0, "generic kfsmd daemon options:", 0 },

            { "verbose", 'v', POPT_ARG_NONE, &Verbose, 0,
              "output more info", "" },
            
            
            POPT_AUTOHELP
            POPT_TABLEEND
        };
    poptContext optCon;

    optCon = poptGetContext(PROGRAM_NAME, argc, (const char**)argv, optionsTable, 0);
    poptSetOtherOptionHelp(optCon, "[OPTIONS]* [IGNOREPFX URL]* [WATCH URL]+ ...");

    
    /* Now do options processing */
    char c=-1;
    while ((c = poptGetNextOpt(optCon)) >= 0)
    {
    }

    daemon->ParseWatchOptions( optCon );
    daemon->setRunInForground( true );
    daemon->setupSignalHandlers();

    daemon->homedir = getHomeDir( homedir_CSTR );

    try
    {
        if( Verbose )
            cerr << "setting up watches" << endl;
        daemon->setupWatches();
        if( Verbose )
            cerr << "calling run" << endl;
        return daemon->run();
    }
    catch( exception& e )
    {
        cerr << "Exiting due to error reason:" << e.what() << endl;
    }
    
    return 0;
}

