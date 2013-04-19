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
    end

    # Fetches a single file from the server
    def self.retrieve_file(metadata_type, full_name)

        if @client == nil
            build_client
        end

        manifest = Metaforce::Manifest.new(metadata_type => [full_name])

        @client.retrieve_unpackaged(manifest).
            extract_to(Atf_Config.src).
            on_complete { |job| puts "Finished retrieve #{job.id}!" }.
            on_error { |job| puts "Something bad happened!" }.
            perform
    end

    # Fetches a whole project from the server
    def self.retrieve_project()

        if @client == nil
            build_client
        end

        if File.file?(Atf_Config.src + '/package.xml')
            @client.retrieve_unpackaged(File.expand_path(Atf_Config.src + '/package.xml')).
                extract_to(Atf_Config.src).
                on_complete { |job| puts "Finished retrieve #{job.id}!" }.
                on_error { |job| puts "Something bad happened!" }.
                perform
        else
            puts "#{Atf_Config.src}: Not a valid project path"
        end
    end

    def self.deploy_project(dpath=Atf_Config.src)

        if @client == nil
            build_client
        end

        if File.file?(dpath + '/package.xml')
            @client.deploy(File.expand_path(dpath)).
                on_complete { |job| puts "Finished deploy #{job.id}!" }.
                on_error { |job| puts "Something bad happened!" }.
                perform
        else
            puts "#{dpath}: Not a valid project path"
        end

    end

    class Atf_Config
        class << self
            attr_accessor :targets, :active_target, :src
            SETTINGS_FILE="./.abusetheforce.yaml"

            # Loads configurations from yaml
            def load()

                if File.file?(SETTINGS_FILE) == false
                    puts "No settings file found, creating one now"
                    # Settings file doesn't exist
                    # Create it
                    @targets = {}
                    @active_target = nil
                    @src = './src'

                    dump_settings
                else
                    settings = YAML.load_file(SETTINGS_FILE)
                    @targets = settings[:targets]
                    @src = settings[:src]
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
                if File.file?(ppath + '/package.xml')
                    @src = ppath
                    dump_settings
                else
                    pute("No package.xml found in #{ppath}", true)
                end
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
            puts "#{@name}\t#{@username}\t#{@host}\t#{(@active && 'Active') || ''}"
        end
    end

end

