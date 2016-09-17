require 'sony_camera_remote_api'
require 'sony_camera_remote_api/scripts'
require 'sony_camera_remote_api/logging'
require 'sony_camera_remote_api/utils'
require 'fileutils'
require 'thor'
require 'highline/import'
require 'yaml'
require 'pp'

module SonyCameraRemoteAPI
  module Client
    module ConfigUtils

      module_function

      # Get default selected camera.
      def default_camera(file)
        # check default camera in configuration file
        yaml = read_config_file file
        unless yaml.key?('default')
          puts 'Default camera is not selected!'
          return nil
        end
        yaml['camera'].find { |n| n['ssid'] == yaml['default'] }
      end

      # Save endpoint information to config file if exists
      def save_ssdp_config(file, endpoints)
        yaml = read_config_file file
        config = yaml['camera'].find { |n| n['ssid'] == yaml['default'] }
        config['endpoints'] = endpoints
        write_config_file file, yaml
      end

      # Read config file.
      # @param [Boolean] assert If +true+, exit when the config file does not exist.
      # @return [Hash] JSON converted from YAML config file.
      def read_config_file(file, assert: true)
        if File.exists? file
          YAML.load_file(file)
        else
          if assert
            puts 'Configuration file not found!'
            exit 1
          end
        end
      end

      # Write config file
      def write_config_file(file, yaml)
        open(file, 'w') do |e|
          YAML.dump(yaml, e)
        end
      end

    end
  end
end



module SonyCameraRemoteAPI
  # CLI client module
  module Client

    # 'config' subcommand class for managing camera connection
    class Config < Thor
      include Utils
      include Scripts
      include ConfigUtils

      class_option :file, aliases: '-f', type: :string, desc: 'Config file path', banner: 'FILE'

      no_tasks do
        def config_file
          options[:file] || GLOBAL_CONFIG_FILE
        end
      end


      desc 'add <SSID> <password> <interface>', 'Register a new camera connection'
      def add(ssid, pass, interface)
        yaml = read_config_file config_file, assert: false
        if yaml.nil? || !yaml.key?('camera')
          yaml = { 'camera' => [{ 'ssid' => ssid, 'pass' => pass, 'interface' => interface }] }
        else
          # if input SSID is already registered, ask user to overwrite
          index = yaml['camera'].index { |n| n['ssid'] == ssid }
          if index
            answer = $terminal.ask('SSID duplicated! Do you want to overwrite? ') { |q| q.validate = /[yn]/i; q.default = 'n' }
            if answer == 'y'
              yaml['camera'][index] = { 'ssid' => ssid, 'pass' => pass, 'interface' => interface }
            else
              puts 'Entry not changed.'
              invoke :list, [], options
              return
            end
          else
            yaml['camera'] << { 'ssid' => ssid, 'pass' => pass, 'interface' => interface }
          end
        end
        # ask user to select as default
        answer = $terminal.ask('Do you want set this camera as default? ') { |q| q.validate = /[yn]/i; q.default = 'y' }
        if answer == 'y'
          yaml['default'] = ssid
        end
        write_config_file config_file, yaml
        invoke :list, [], options
      end


      desc 'list', 'List registered cameras'
      def list
        yaml = read_config_file config_file
        if yaml['camera'].uniq! { |v| v['ssid'] }
          puts 'Removed duplicated entries.'
          write_config_file config_file, yaml
        end
        if yaml.key? 'camera'
          # selected camera is signed by allow
          yaml['camera'].each_with_index do |v, i|
            if v['ssid'] == yaml['default']
              puts "=> #{i}: SSID      : #{v['ssid']} "
            else
              puts "   #{i}: SSID      : #{v['ssid']} "
            end
            puts "      Password  : #{v['pass']} "
            puts "      Interface : #{v['interface']} "
          end
        else
          # no camera is registered
          puts 'No camera!'
          puts "To add new camera connection, use 'sonycam config add' command."
        end
        # default camera is not selected
        unless yaml.key? 'default'
          puts 'Currently no camera is selected as default!'
          puts "To select a camera as default from the list above, use 'sonycam config use' command."
        end
      end


      desc 'remove [options]', 'Unregister a camera'
      option :all, type: :boolean, desc: 'Remove all cameras'
      option :id, aliases: '-i', type: :numeric, desc: "Specify camera by ID, which can be seen by 'config list' command", banner: 'NUMBER'
      option :ssid, aliases: '-s', type: :string, desc: 'Specify camera by SSID'
      def remove
        unless [options[:id], options[:ssid], options[:all]].one?
          puts "use either option '--all', '--id', '--ssid' to specify camera"
          return
        end

        yaml = read_config_file config_file
        if options[:all]
          # remove all entries
          write_config_file config_file, {}
          return
        end
        if options[:id]
          # remove ID'th entry
          if 0 <= options[:id] && options[:id] < yaml['camera'].size
            yaml.delete_if { |k, v| k == 'default' && v == yaml['camera'][options[:id]]['ssid'] }
            yaml['camera'].delete_at options[:id]
            write_config_file config_file, yaml
          else
            puts 'ERROR: Specified ID is invalid!'
          end
        elsif options[:ssid]
          # find entry that matches specified SSID exactly
          result, num = partial_and_unique_match(options[:ssid], yaml['camera'].map { |e| e['ssid'] })
          if result
            yaml.delete_if { |k, v| k == 'default' && v == result }
            yaml['camera'].delete_if { |e| e['ssid'] == result }
            write_config_file config_file, yaml
          else
            if num > 1
              puts 'ERROR: Specified SSID is ambigous!'
            elsif num == 0
              puts 'ERROR: Specified SSID is not found!'
            end
          end
        end
        invoke :list, [], options
      end


      desc 'use <SSID>', 'Select a camera as default'
      option :id, aliases: '-i', type: :numeric, desc: "Specify camera by ID, which can be seen by 'config list' command", banner: 'NUMBER'
      option :ssid, aliases: '-s', type: :string, desc: 'Specify camera by SSID'
      def use
        unless [options[:id], options[:ssid]].one?
          puts "use either option '--id' or '--ssid' to specify camera"
          return
        end

        yaml = read_config_file config_file

        if options[:id]
          # select ID'th entry
          if 0 <= options[:id] && options[:id] < yaml['camera'].size
            yaml['default'] = yaml['camera'][options[:id]]['ssid']
            write_config_file config_file, yaml
          else
            puts 'ERROR: Specified ID is invalid!'
          end
        elsif options[:ssid]
          # find entry that matches specified SSID exactly
          result, num = partial_and_unique_match(options[:ssid], yaml['camera'].map { |e| e['ssid'] })
          if result
            yaml['default'] = result
            write_config_file config_file, yaml
          else
            # find entry that matches specified SSID partially but identically
            if num > 1
              puts 'ERROR: Specified SSID is ambigous!'
            elsif num == 0
              puts 'ERROR: Specified SSID is not found!'
            end
          end
        end
        invoke :list, [], options
      end


      desc 'default', 'Show the current default camera'
      option :json, type: :boolean, desc: 'output in JSON format'
      def default
        config = default_camera config_file
        return if config.nil?

        if options[:json]
          puts JSON.pretty_generate config
        else
          puts "SSID      : #{config['ssid']} "
          puts "Password  : #{config['pass']} "
          puts "Interface : #{config['interface']} "
        end
      end


      desc 'connect', 'Connect to the current default camera'
      option :restart, aliases: '-r', type: :boolean, desc: 'Restart interface', default: false
      def connect
        config = default_camera config_file
        return if config.nil?

        puts 'Selected camera:'
        puts "  - SSID     : #{config['ssid']}"
        puts "  - pass     : #{config['pass']}"
        puts "  - inteface : #{config['interface']}"

        # Connect to camera by external script
        if options[:restart]
          result = Scripts.restart_and_connect(config['interface'], config['ssid'], config['pass'])
        else
          result = Scripts.connect(config['interface'], config['ssid'], config['pass'])
        end
        unless result
          puts 'Failed to connect!'
          exit 1
        end
      end
    end
  end
end
