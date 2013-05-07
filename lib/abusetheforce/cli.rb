require 'thor'
require 'highline/import'
require 'abusetheforce/version'

module AbuseTheForce

    # MODULE METHODS

    # Toggle to a new target temporarily
    def self.temp_switch_target(name=nil)
        # If a name was provided, switch to that
        if name != nil
            # Store the original target's name
            @last_target = Atf_Config.active_target.name
            # Switch to the new target
            Atf_Config.set_active_target name
        else
            # Switch back to the old target
            Atf_Config.set_active_target @last_target
        end
    end

    # Safe prompt for password
    def self.get_password(prompt="Enter Password: ")
       ask(prompt) {|q| q.echo = false}
    end

    class TargetCLI < Thor
        
        desc "add <alias> <username> <security token> [--sandbox]", "Adds a new remote target"
        long_desc <<-LONG_DESC
            Adds a new target org with the alias <alias> to your atf.yaml file
            with the provided <username>, <security token> and prompted password.

            With -s or --sandbox option, sets host to "test.salesforce.com" 

            To perform any actions you must have a valid target added 
        LONG_DESC
        option :sandbox, :type => :boolean, :aliases => :s, :default => false
        def add(name, username, security_token)
            password = AbuseTheForce.get_password
            host = (options[:sandbox] ? "test.salesforce.com" : "login.salesforce.com")

            # Add the target to the config
            Atf_Config.add_target(Atf_Target.new(name, username, password, security_token, host))
        end

        desc "update <alias> [--password | --sandbox=<true/false> | --token=<token>]", "Updates a remote target"
        long_desc <<-LONG_DESC
            Updates a part of target with <alias>

            -p or --password option, prompts you for an updated password

            -s or --sandbox <true/false> option, switches the host to sandbox or production

            --token=<security token> option, sets the security token to the value provided

            The changes will then be written to the .abusetheforce.yaml file
        LONG_DESC
        option :password, :type => :boolean, :aliases => :p, :default => false, :desc => "Prompt for password"
        option :token, :banner => "<security token>"
        option :sandbox, :type => :boolean, :aliases => :s, :desc => "Add this if deploying to a sandbox"
        def update(name)

            target = Atf_Config.targets[name]

            if target != nil
                if options[:password]
                    target.set_password AbuseTheForce.get_password
                end
                if options[:token] != nil
                    target.security_token = options[:token]
                end
                if options[:sandbox] != nil
                    target.host = (options[:sandbox] ? "test.salesforce.com" : "login.salesforce.com")
                end
            else
                AbuseTheForce.pute("Target not found", true)
            end

            # Save to yaml
            Atf_Config.dump_settings
        end

        desc "remove <alias>", "Removes a remote target"
        def remove(name)
            Atf_Config.targets.delete name
            # Save to yaml
            Atf_Config.dump_settings
        end

        desc "activate <alias>", "Activates specified target"
        long_desc <<-LONG_DESC
            Activates the target specified by <alias>.

            You must have an active target to perform any actions
        LONG_DESC
        def activate(name)
            # Activate the target
            Atf_Config.set_active_target name
        end

        desc "current", "Shows currently active target"
        def current()

            if Atf_Config.active_target != nil
                Atf_Config.active_target.print
            else
                AbuseTheForce.putw "No active target set"
            end
        end

        desc "list", "Lists all targets"
        def list()
            puts "Name\t\tUsername"

            Atf_Config.targets.values.each do |target|
                target.print
            end

        end

        # By default, display the current target
        default_task :current
    end

    class DeployCLI < Thor
        class_option :target, :banner => "<target alias>", :aliases => :t
        #class_option :delete, :aliases => :d

        TEMP_DIR=".atf_tmp"
        RESOURCE_DIR="resources"

        desc "file <path to file>", "Deploy a single file"
        long_desc <<-LONG_DESC
            Deploys file at path <path to file> to the active target.
        LONG_DESC
        def file(fpath)

            # Make the filepath absolute
            fpath = File.absolute_path fpath
            abs_root = File.absolute_path Atf_Config.root_dir

            # Check that file path is in root dir
            unless fpath.starts_with? abs_root
                pute("File does not exist within root project: #{Atf_Config.root_dir}", true)
            end

            # Check if in resource directory
            if fpath.starts_with? File.join(abs_root, RESOURCE_DIR)
                # This is a resource file
                # Zip the resource up and then deploy new fpath

                resource_path = File.dirname fpath

                # Until we find the parent directory of the current location is the root resource dir
                until File.dirname(resource_path) == File.join(abs_root, RESOURCE_DIR)
                    # Go up to the next parent
                    resource_path = File.dirname resource_path
                end

                # TODO: Extract this logic for full deploy as well
                resource_path = resource_path
                resource_name = File.basename resource_path

                zip_path = File.join(Atf_Config.get_project_path, 'staticresources', resource_name + '.resource') 

                # TODO: Find a better place to stare XML templates
                static_resource_xml = <<-eos
<?xml version="1.0" encoding="UTF-8"?>
<StaticResource xmlns="http://soap.sforce.com/2006/04/metadata">
    <cacheControl>Public</cacheControl>
    <contentType>application/zip</contentType>
    <description>Static resource uploaded with Abuse the Force</description>
</StaticResource>
                eos

                # Compress the resource
                `cd $(dirname "#{resource_path}") && zip -r #{zip_path} #{resource_name}`

                # Write the meta.xml
                File.open(zip_path + '-meta.xml', 'w') {|f| f.write(static_resource_xml) }

                # Set the fpath to the new zip file
                fpath = zip_path
            end

            # Get path to temp project directory
            temp_path = File.join(Atf_Config.root_dir, TEMP_DIR)

            # If a new target was provided, switch to it
            if options[:target] != nil
                AbuseTheForce.temp_switch_target options[:target]
            end

            # Clear temp dir
            if Dir.exists? temp_path
                FileUtils.rm_r temp_path
            end

            # Get the metadata directory right before filename
            mdir = File.basename(File.dirname(fpath))

            # Create the temp directories
            FileUtils.mkdir_p File.join(temp_path, mdir)

            # Copy the package file
            FileUtils.copy(
                File.join(Atf_Config.get_project_path, 'package.xml'), 
                File.join(temp_path, 'package.xml')
            )
            # File basename
            basename = File.basename fpath

            # Copy the file
            FileUtils.copy(
                File.join(Atf_Config.get_project_path, mdir, basename), 
                File.join(temp_path, mdir, '/')
            )

            # Copy the metadata
            FileUtils.copy(
                File.join(Atf_Config.get_project_path, mdir, basename + '-meta.xml'), 
                File.join(temp_path, mdir, '/')
            )

            AbuseTheForce.deploy_project temp_path

            # if using a temp target, switch back
            if options[:target] != nil
                AbuseTheForce.temp_switch_target
            end
        end

        desc "project", "Deploy a whole project"
        def project(target=nil)

            # If a new target was provided, switch to it
            if options[:target] != nil
                target = options[:target]
            end
            if target != nil
                AbuseTheForce.temp_switch_target target
            end

            # Deploy the project
            AbuseTheForce.deploy_project()

            # if using a temp target, switch back
            if target != nil
                AbuseTheForce.temp_switch_target
            end
        end
    end

    class RetrieveCLI < Thor
        class_option :target, :banner => "<target alias>", :aliases => :t
        #class_option :delete, :aliases => :d

        desc "file <file> [metadata type]", "Retrieve a single file"
        long_desc <<-LONG_DESC
            Retrieves one file from the active target

            This has two uses:

            To retrieve a file not on the local machine, provide the name of the
            file and the metadata type.

            Example: $atf retrieve file MyClassName ApexClass

            To retrieve a new version of a file already local to you, you just
            provide the path to the file.

            Example: $atf retrieve file ./src/classes/MyClass

            NOTE: Must be called from the root project directory
        LONG_DESC
        def file(full_name, metadata_type=nil)
            # TODO: Work backwards if called not in child of project directory

            # If a new target was provided, switch to it
            if options[:target] != nil
                AbuseTheForce.temp_switch_target options[:target]
            end

            # No metadata passed in, this should be a file path
            if metadata_type == nil
                if File.file? full_name
                    # Get the file extension
                    extname = File.extname full_name
                    # Get the base name of the metadata
                    full_name = File.basename(full_name, extname)

                    # Detect metadata type by file extension
                    case extname
                    when '.cls'
                        metadata_type = 'ApexClass'
                    when '.trigger'
                        metadata_type = 'ApexTrigger'
                    when '.object'
                        metadata_type = 'CustomObject'
                    when '.page'
                        metadata_type = 'ApexPage'
                    when '.component'
                        metadata_type = 'ApexComponent'
                    else
                        AbuseTheForce.pute('Unrecognized file type', true)
                    end
                end
            end

            # retrieve the file using metaforce
            AbuseTheForce.retrieve_file(metadata_type, full_name)

            # if using a temp target, switch back
            if options[:target] != nil
                AbuseTheForce.temp_switch_target
            end
        end

        desc "project", "Retrieve a whole project"
        def project(target=nil)

            # If a new target was provided, switch to it
            if options[:target] != nil
                target = options[:target]
            end
            if target != nil
                AbuseTheForce.temp_switch_target target
            end
            
            # Retrieve the project
            AbuseTheForce.retrieve_project

            # if using a temp target, switch back
            if target != nil
                AbuseTheForce.temp_switch_target
            end
        end
    end
     
    # AbUse The Force
    class AtfCLI < Thor

        # Load the abuse-the-force config
        Atf_Config.load

        # ATF Subcommands
        desc "target SUBCOMMAND ...ARGS", "Manage deploy targets"
        subcommand "target", TargetCLI

        desc "deploy SUBCOMMAND ...ARGS", "Deploy code to Salesforce.com"
        subcommand "deploy", DeployCLI

        desc "retrieve SUBCOMMAND ...ARGS", "Retrieve code from Salesforce.com"
        subcommand "retrieve", RetrieveCLI

        desc "version", "Version information"
        def version
            puts "version #{AbuseTheForce::VERSION}"
        end

    end

end # end module AbuseTheForce
 

