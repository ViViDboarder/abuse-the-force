Abuse the Force
===============

A tool expanding upon [Metaforce](https://github.com/ejholmes/metaforce) for deploying to
multiple orgs as well as simpler setup for use as a pseudo compiler

Features
--------
* Store orgs config file for easy switching between deploy targets
* Familiar command sub-command interface (think git)
* Deploy single files without deploying the entire project
* Execute test class
* Deploy a list of specific files to deploy
* [Vim plugin](https://github.com/ViViDboarder/vim-abuse-the-force)
* [Sublime plugin](https://github.com/ViViDboarder/sublime-abuse-the-force)

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
    # Deploy a single file
    atf deploy file src/classes/MyClass.cls
    # Run a test class
    atf deploy test src/classes/MyClassTest.cls
    # Retrieve a single file
    atf retrieve file src/objects/Opportunity.object

More advanced documentation can be found by running any of the `help` commands.

    atf help
    atf deploy help
    atf retrieve help
    atf target help

Deploy List
-----------
Deploy list gives you an easy way to only deploy files that have changed. This works really well if you are
using some kind of version control.

It takes a file of the format:

    src/classes/MyClass.cls
    src/triggers/MyTrigger.trigger

You can generate a file like this using `git diff --no-commit-id --name-only` or the script included 
in the `examples` directory.

Why This Over Metaforce?
------------------------
* Vim and Sublime plugins
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


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/ViViDboarder/abuse-the-force/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

