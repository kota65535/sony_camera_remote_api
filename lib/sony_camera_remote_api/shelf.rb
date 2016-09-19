require 'sony_camera_remote_api/utils'
require 'sony_camera_remote_api/scripts'
require 'yaml'


module SonyCameraRemoteAPI
  class Shelf
    include Utils

    # Default config file saved in home directory.
    GLOBAL_CONFIG_FILE = File.expand_path('~/.sonycamconf')


    # Create CameraShelf object.
    # @param [String] config_file The path of config file.
    def initialize(config_file = GLOBAL_CONFIG_FILE)
      @config_file = config_file
      read_or_create
    end


    # Get a camera config by SSID.
    # You can use a partial string as long as it is unique.
    # @param [String] ssid SSID
    # @return [Hash, nil] A camera config hash
    def get(ssid)
      get_unique(ssid)
    end


    # Get all camera configs.
    # @return [Array<Hash>] An array of camera config hashes
    def get_all
      @config['camera']
    end


    # Get a camera config by index.
    # @param [String] index Index
    # @return [Hash, nil]   A camera config hash
    def get_by_index(index)
      if index.between? 0, @config['camera'].size - 1
        @config['camera'][index]
      end
    end


    # Add a camera config.
    # @param [Boolean] overwrite Overwrite if the same SSID's config is already added.
    # @return [Boolean] +true+ if successfully added, +false+ otherwise.
    def add(ssid, pass, interface, overwrite: false)
      # If input SSID is already registered, ask user to overwrite
      same_one = @config['camera'].find { |n| n['ssid'] == ssid }
      if same_one && !overwrite
        false
      else
        @config['camera'].delete_if { |c| c['ssid'] == ssid }
        @config['camera'] << { 'ssid' => ssid, 'pass' => pass, 'interface' => interface }
        if @config['camera'].size == 1
          @config['default'] = ssid
        end
        write
      end
    end


    # Remove a camera config.
    # @return [Boolean] +true+ if successfully removed, +false+ otherwise.
    def remove(ssid)
      entry = get_unique(ssid)
      if @config['camera'].delete entry
        write
      else
        false
      end
    end


    # Remove all camera configs.
    # @return [Boolean] +true+ if successfully removed, +false+ otherwise.
    def remove_all
      create
    end


    # Remove a camera config by index.
    # @param [String] index Index
    # @return [Hash, nil]   A camera config hash
    def remove_by_index(index)
      if index.between? 0, @config['camera'].size - 1
        @config['camera'].delete_at index
        write
      else
        false
      end
    end


    # Set endpoint information to a camera config.
    # @return [Boolean] +true+ if successfully set endpoints, +false+ otherwise.
    def set_endpoints(ssid, endpoints)
      entry = get_unique(ssid)
      if entry
        entry['endpoints'] = endpoints
        write
      else
        false
      end
    end


    # Get the default camera config.
    # @return [Hash, nil] A camera config hash
    def get_default
      @config['camera'].find { |c| c['ssid'] == @config['default'] }
    end


    # Set the camera config as default.
    # @return [Boolean] +true+ if successfully set default camera, +false+ otherwise.
    def set_default(ssid)
      entry = get(ssid)
      if entry
        @config['default'] = entry['ssid']
        write
      else
        false
      end
    end


    # Set interface by which the camera is connected.
    # @return [Boolean] +true+ if successfully set default camera, +false+ otherwise.
    def set_interface(ssid, interface)
      entry = get(ssid)
      if entry
        entry['interface'] = interface
        write
      else
        false
      end
    end


    def connect(ssid = nil)
      if ssid.nil?
        entry = get_default
      else
        entry = get(ssid)
      end
      if entry
        Scripts.connect entry['interface'], entry['ssid'], entry['pass']
      else
        false
      end
    end


    private

    # @param [Hash, nil]
    def get_unique(ssid)
      complete_ssid, num = partial_and_unique_match(ssid, @config['camera'].map { |c| c['ssid'] })
      return unless num == 1
      @config['camera'].find { |c| c['ssid'] == complete_ssid }
    end

    # @return [Boolean]
    def read_or_create
      unless read
        create
      else
        false
      end
    end

    # @return [Boolean]
    def create
      @config = { 'camera' => [] }
      write
    end

    # @return [Boolean]
    def read
      if File.exists? @config_file
        @config = YAML.load_file(@config_file)
      end
      @config.present? ? true : false
    end

    # @return [Boolean]
    def write
      open(@config_file, 'w') do |e|
        YAML.dump(@config, e)
      end
      true
    end
  end
end
