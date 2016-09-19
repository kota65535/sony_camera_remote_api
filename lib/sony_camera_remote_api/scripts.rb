require 'open3'

module SonyCameraRemoteAPI
  # Helper module for connecting to camera by wi-fi.
  module Scripts

    module_function

    # Connects to camera by Wi-Fi.
    # This method does nothing if already connected, which is judged by ifconfig command.
    # @param [String] interface Interface name, e.g. wlan0
    # @param [String] ssid SSID of the camera to connect
    # @param [String] pass Password of the camera to connect
    # @return [Boolean] +true+ if succeeded, +false+ otherwise.
    def connect(interface, ssid, pass)
      run_external_command "sudo bash #{connection_script} #{interface} #{ssid} #{pass}"
    end


    # Restart the interface and connect to camera by Wi-Fi.
    # @param [String] interface Interface name, e.g. wlan0
    # @param [String] ssid SSID of the camera to connect
    # @param [String] pass Password of the camera to connect
    # @return [Boolean] +true+ if succeeded, +false+ otherwise.
    def restart_and_connect(interface, ssid, pass)
      run_external_command "sudo bash #{connection_script} -r #{interface} #{ssid} #{pass}"
    end


    # Run shell command.
    # Command output are written to stdout witout buffering.
    # @param [String] command Command to execute
    # @return [Boolean] +true+ if succeeded, +false+ otherwise.
    def run_external_command(command)
      puts command
      Open3.popen2e(command) do |_i, oe, w|
        oe.each do |line|
          puts line
        end
        # Return code
        if w.value != 0
          return false
        else
          return true
        end
      end
    end

    # Get gem root path (not smart)
    def root
      File.expand_path '../../..', __FILE__
    end

    # Path where scripts are located
    def path
      File.join root, 'scripts'
    end

    # Full path of connection script
    def connection_script
      File.join path, 'connect.sh'
    end

  end
end
