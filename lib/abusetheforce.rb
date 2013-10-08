require "metaforce"
require "base64"

module AbuseTheForce
    attr_accessor :client

    # Write error to screen
    def self.pute(s, fatal=false)
        puts "Error: #{s}"

        # If fatal error, exit
        if fatal
            exit 1
        end
    end

    # Write warning to screen
    def self.putw(s)
        puts "Warning: #{s}"
    end

    # builds the client instance of Metaforce
    def self.build_client
        target = Atf_Config.active_target

        puts target.username

        @client = Metaforce.new :username => target.username,
            :password => target.get_password,
            :security_token => target.security_token

        Metaforce.configuration.host = target.host

        # Supress some of the verbose logging
        Metaforce.configuration.log = false
    end

    # Fetches a single file from the server
    def self.retrieve_file(metadata_type, full_name)

        if @client == nil
            build_client
        end

        # Backup old Manifest
        FileUtils.copy(
            File.join(Atf_Config.get_project_path, 'package.xml'),
            File.join(Atf_Config.get_project_path, 'package.xml-bak')
        )

        manifest = Metaforce::Manifest.new(metadata_type => [full_name])

        @client.retrieve_unpackaged(manifest).
            extract_to(Atf_Config.get_project_path).
            on_complete { |job| puts "Finished retrieve #{job.id}!" }.
            on_error { |job| puts "Something bad happened!" }.
            on_poll { |job| puts "Polling for #{job.id}!" }.
            perform

        # Restore old Manifest
        FileUtils.move(
            File.join(Atf_Config.get_project_path, 'package.xml-bak'),
            File.join(Atf_Config.get_project_path, 'package.xml')
        )
    end

    # Fetches a whole project from the server
    def self.retrieve_project()

        if @client == nil
            build_client
        end

        if File.file? File.join(Atf_Config.get_project_path, 'package.xml')
            @client.retrieve_unpackaged(File.expand_path(Atf_Config.src + '/package.xml')).
                extract_to(Atf_Config.get_project_path).
                on_complete { |job| puts "Finished retrieve #{job.id}!" }.
                on_error { |job| puts "Something bad happened!" }.
                on_poll { |job| puts "Polling for #{job.id}!" }.
                perform
        else
            puts "#{Atf_Config.get_project_path}: Not a valid project path"
        end
    end

    def self.deploy_test(dpath, test_name)

        options = { :run_tests => [ test_name ], :rollback_on_error => true }

        deploy_project(dpath, options)
    end

    def self.deploy_project(dpath=Atf_Config.get_project_path, options={ :rollback_on_error => true })

        if @client == nil
            build_client
        end

        # Set auto update
        options[:auto_update_package] = true

        if File.file? File.join(dpath, 'package.xml')
            @client.deploy(File.expand_path(dpath), options).
                on_complete { |job|
                    puts "Finished deploy #{job.id}!"
                    result = job.result
                    if result != nil

                        # Check if this was a test execution
                        if options[:run_tests] != nil

                            # Display a quick Success or Failure
                            puts "\nTests #{result.run_test_result.num_failures == "0" ? "SUCCESS" : "FAILURE"}"

                            # Display overview of number of successes and failures
                            puts "TESTS RUN: #{result.run_test_result.num_tests_run} FAILURES: #{result.run_test_result.num_failures}"

                            if result.run_test_result.failures != nil

                                # Make sure failures is an array
                                unless result.run_test_result.failures.kind_of? Array
                                    result.run_test_result.failures = [].push result.run_test_result.failures
                                end

                                result.run_test_result.failures.each do |m|

                                    # Print our error in teh format "filename:line:column type in object message"
                                    if !m.success
                                        puts "#{m.name}.#{m.method_name}: #{m.message}"
                                        puts "Stack Trace: #{m.stack_trace}"
                                        puts ""
                                    end # not success
                                end # loop through test faiulres
                            end # failures != nil
                        else # run_test_result != nil

                            puts "\nDeploy #{result.success ? "SUCCESS" : "FAILURE"}"

                            # Not a test execution, so deployment

                            # If a failed deploy, print errors
                            if result.success == false

                                # Need messages in an array
                                unless result.messages.kind_of? Array
                                    result.messages = [].push result.messages
                                end

                                puts "DEPLOY ERRORS: #{result.messages.reject { |m| m.success }.size}"

                                result.messages.each do |m|

                                    # If the path is not from the project, fix it
                                    unless m.file_name.starts_with? Atf_Config.src
                                        m.file_name = m.file_name.sub(/[a-zA-Z._-]*\//, Atf_Config.src + '/')
                                    end

                                    # Print our error in teh format "filename:line:column type in object message"
                                    if !m.success
                                        puts "#{m.file_name}:#{m.line_number}:#{m.column_number} #{m.problem_type} in #{m.full_name} #{m.problem}"
                                    end
                                end
                            end # success == false
                        end # end result.run_test_result != null else
                    end # result != nil
                }.
                on_error { |job| puts "Something bad happened!" }.
                on_poll { |job| puts "Polling for #{job.id}!" }.
                perform
        else
            puts "#{dpath}: Not a valid project path"
        end

    end

    class Atf_Config
        class << self
            attr_accessor :targets, :active_target, :src, :root_dir
            SETTINGS_FILE=".abusetheforce.yaml"

            def locate_root(path = '.')

                temp_path = path

                # Look for a settings file in this path and up to root
                until File.file? File.join(temp_path, SETTINGS_FILE)
                    # If we hit root, stop
                    if temp_path == '/'
                        break
                    end

                    # Didn't find one so go up one level
                    temp_path = File.absolute_path File.dirname(temp_path)
                end

                # If we actually found it
                if File.file? File.join(temp_path, SETTINGS_FILE)
                    # Return
                    return temp_path
                else
                    # Return the original path
                    return path
                end

            end

            # Loads configurations from yaml
            def load()

                # Get the project root directory
                @root_dir = locate_root

                if File.file? File.join(@root_dir, SETTINGS_FILE)
                    settings = YAML.load_file File.join(@root_dir, SETTINGS_FILE)
                    @targets = settings[:targets]
                    @src = settings[:src]
                else
                    puts "No settings file found, creating one now"
                    # Settings file doesn't exist
                    # Create it
                    @targets = {}
                    @active_target = nil
                    @src = './src'

                    dump_settings
                end

                # Set the default target
                @targets.values.each do |target|
                    # Check if this one is active
                    if target.active == true
                        # Set it if there is no default target set yet
                        if @active_target == nil
                            @active_target = target
                        else
                            puts "Two active targets set. Using #{@active_target.print}"
                        end
                    end
                end
            end

            # write settings to a yaml file
            def dump_settings
                File.open(SETTINGS_FILE, 'w') do |out|
                    YAML.dump( { :targets => @targets, :src => @src }, out)
                end
            end

            # Adds a new target to the config
            def add_target(target)

                # If there are no targets yet, use this one as the default
                if @active_target == nil #@targets.empty?
                    target.active = true
                    @active_target = target
                end

                # Push the new target
                @targets[target.name] = target

                #write out the config
                dump_settings

                puts "Target Added"
                target.print
            end

            # Selects one target as the active target for deployment
            def set_active_target(name)

                # Empty out current active target
                @active_target = nil

                # Go through each pair
                @targets.each_pair do |target_name, target|
                    # If you find a matching item
                    if name == target_name
                        # Check if there is already a default
                        if @active_target == nil
                            # Set active
                            target.active = true
                            # Make it default
                            @active_target = target
                        end
                    else # name != name
                        # make not active
                        target.active = false
                    end
                end

                if @active_target != nil
                    # Save to yaml
                    dump_settings
                    # Notify the user
                    puts "Active target changed"
                    @active_target.print
                else
                    AbuseTheForce.pute "Target with alias #{name} was not found."
                end

            end

            # Sets project path from default ./src
            def set_project_path(ppath)
                if File.file? File.join(ppath, 'package.xml')
                    @src = ppath
                    dump_settings
                else
                    pute("No package.xml found in #{ppath}", true)
                end
            end

            # Gets the full path to the src folder
            def get_project_path
                return File.absolute_path File.join(root_dir, src)
            end

        end
    end

    # Class for holding a target
    class Atf_Target
        attr_accessor :name, :username, :password, :security_token, :host, :active

        def initialize(name, username, password, security_token, host="login.salesforce.com")
            @name = name
            @username = username
            set_password(password)
            @security_token = security_token
            @host = host
            @active = false;
        end

        # TODO: Provide 2 way encryption with a lock to decode passwords
        def set_password(password)
            @password = Base64.encode64(password)
        end

        def get_password()
            return Base64.decode64(@password)
        end

        def print
            #puts "#{@name}\t#{@username}\t#{@host}\t#{(@active && 'Active') || ''}"
            puts "#{(@active ? '*' : ' ')} #{@name}\t\t#{@username}\t#{(@host.starts_with?('test') ? 'sandbox' : '')}\t"
        end
    end

end

