Abuse the Force
===============

A tool expanding upon [Metaforce](https://github.com/ejholmes/metaforce) for deploying to
multiple orgs as well as simpler setup for use as a pseudo compiler

Features
--------
* Store orgs config file for easy switching between deploy targets
* Familiar command sub-command interface (think git)
* Deploy single files without deploying the entire project
* [Vim plugin](https://github.com/ViViDboarder/vim-abuse-the-force)

Usage
-----
Much like git, you initialize your project directory by adding your deploy targets first. 
Once you have one set you can view the active target with `atf target`. If you want to deploy
from there you just execute one of the deploy commands.

**Simple Setup Example**
    
    # Add production
    atf target add production vividboarder@mycompany.com MY_SECURITY_TOKEN
    # Deploy to production
    atf deploy project
    # Add a sandbox
    atf target add sandbox vividboarder@mycompany.com.sandbox MY_SECURITY_TOKEN --sandbox
    # Switch active targets
    atf target activate sandbox
    # Deploy to sandbox
    atf deploy project

More advanced documentation can be found by running any of the `help` commands.

    atf help
    atf deploy help
    atf retrieve help
    atf target help

Why This Over Metaforce?
------------------------
* Vim and Sublime plugins (coming soon...)
* Command line configuration management
* Options for deploying or retrieving a single file
* Encrypted Passwords coming soon

Installation
------------
Must have ruby 1.9 and gem installed

    git clone git://github.com/ViViDboarder/abuse-the-force.git
    cd abuse-the-force
    gem build abusetheforce.gemspec
    gem install abusetheforce-X.X.X.gem # make sure the proper version is present

Todo
----
* See Issues tab
