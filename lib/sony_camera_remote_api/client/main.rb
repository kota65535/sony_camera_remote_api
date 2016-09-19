require 'sony_camera_remote_api'
require 'sony_camera_remote_api/logging'
require 'sony_camera_remote_api/scripts'
require 'sony_camera_remote_api/client/shelf'
require 'fileutils'
require 'thor'
require 'highline/import'
require 'yaml'
require 'time'
require 'pp'

module SonyCameraRemoteAPI
  # CLI client module
  module Client

    # Default config file saved in home directory.
    GLOBAL_CONFIG_FILE = File.expand_path('~/.sonycamconf')

    class Main < Thor
      include Utils
      include Scripts

      register ShelfCmd, 'shelf', 'shelf [commands] [options]', 'Managing camera connections'

      # Global options
      class_option :setting, type: :boolean, desc: 'Show current camera settings'
      class_option :output, type: :string, desc: 'Output filename', banner: 'FILE'
      class_option :dir, type: :string, desc: 'Output directory', banner: 'DIR'
      class_option :config, aliases: '-c', type: :string, desc: 'Config file path', banner: 'FILE'
      class_option :ssid, type: :string, desc: 'SSID of the camera to connect'
      class_option :verbose, type: :numeric, desc: 'Increase verbosity', banner: 'LEVEL'

      no_tasks do
        def config_file
          options[:config] || GLOBAL_CONFIG_FILE
        end

        def load_camera_config
          # If SSID is specified, load the camera config.
          if options[:ssid]
            @shelf.get options[:ssid] || @shelf.get_default
          else
            @shelf.get_default
          end
        end

        # Load camera config and connect
        def load_and_connect
          config = load_camera_config
          unless config
            puts 'Failed to load camera config!'
            exit 1
          end
          unless Scripts.connect(config['interface'], config['ssid'], config['pass'])
            puts 'Failed to connect!'
            exit 1
          end
          config
        end

        # Initialize camera instance
        def init_camera
          @shelf = Shelf.new config_file
          config = load_and_connect

          puts 'Initializing camera...'
          if config['endpoints'].nil?
            @cam = SonyCameraRemoteAPI::Camera.new reconnect_by: method(:load_and_connect)
            @shelf.set_endpoints config['ssid'], @cam.endpoints
            puts 'SSDP configuration saved.'
          else
            @cam = SonyCameraRemoteAPI::Camera.new endpoints: config['endpoints'],
                                                   reconnect_by: method(:load_and_connect)
          end
          puts 'Camera initialization finished.'

          # Change directory if --dir options specified
          @cwd = Dir.getwd
          if options[:dir]
            FileUtils.mkdir_p options[:dir]
            Dir.chdir options[:dir]
          end
        end

        # Finalizer
        def finalize
          Dir.chdir @cwd
        end

        # Get supported/available/current camera parameters and show them
        def get_parameter_and_show(param_name, **opts)
          param_title = param_name.to_s.split(/(?=[A-Z])/).join(' ')
          result = @cam.get_parameter! param_name, timeout: 0
          # nil current value means it is unsupported parameter.
          return if result[:current].nil?

          puts "#{param_title}:"
          case param_name
            when :WhiteBalance
              show_WhiteBalance result
            else
              show_normal result
          end
          result
        end

        # Show for other parameter
        def show_normal(result)
          array = []
          if result[:supported].empty?
            # If current value is present but NO supported value, it is immutable.
            result[:supported] = [result[:current]]
          end
          result[:supported].each_with_index do |v, i|
            if v == result[:current]
              array << "  => #{v} "
            elsif result[:available].include? v
              array << "   * #{v} "
            else
              array << "   x #{v}"
            end
          end
          print_array_in_columns(array, 120, 10, 5)
        end

        # Show for WhiteBalance parameter
        def show_WhiteBalance(result)
          array = []
          if result[:supported].empty?
            # If current value is present but NO supported value, it is immutable.
            result[:supported] = [result[:current]]
          end
          result[:supported].each_with_index do |v, i|
            if v.key?('colorTemperature')
              range = "#{v['colorTemperature'][0]}-#{v['colorTemperature'][-1]}K"
              step = v['colorTemperature'][1] - v['colorTemperature'][0]
              if v['whiteBalanceMode'] == result[:current]['whiteBalanceMode']
                str = "#{v['whiteBalanceMode']}, #{result[:current]['colorTemperature']}K  (#{range}, step=#{step})"
              else
                str = "#{v['whiteBalanceMode']}  (#{range}, step=#{step})"
              end
            else
              str = "#{v['whiteBalanceMode']}"
            end
            if v['whiteBalanceMode'] == result[:current]['whiteBalanceMode']
              array << "  => #{str}"
            elsif result[:available].include? v
              array << "   * #{str}"
            else
              array << "   x #{str}"
            end
          end
          print_array_in_columns(array, 120, 10, 5)
        end

        # Set parameter if value is set
        def set_parameter(param_name, value, **opts)
          return if value.is_a?(Hash) && value.values.none?
          return unless value
          @cam.set_parameter! param_name, value, timeout: 0
        end
      end

      #----------------------------------------PARAMETER CONFIGURATORS----------------------------------------

      no_tasks do
        # Set common options for all shooting modes
        def set_common_options
          set_parameter :ZoomSetting, options[:zoom_mode]
          set_parameter :FocusMode, options[:focus_mode]
          set_parameter :ExposureMode, options[:exposure]
          set_parameter :ExposureCompensation, options[:ev].to_f if options[:ev]
          set_parameter :FNumber, options[:fnum]
          set_parameter :ShutterSpeed, options[:shutter]
          set_parameter :IsoSpeedRate, options[:iso]
          if options[:temp]
            set_parameter :WhiteBalance, whiteBalanceMode: options[:wb], colorTemperature: options[:temp]
          else
            set_parameter :WhiteBalance, whiteBalanceMode: options[:wb]
          end

          set_parameter :SceneSelection, options[:scene]
          set_parameter :FlipSetting, options[:flip]
          set_parameter :TvColorSystem, options[:tv]
          set_parameter :InfraredRemoteControl, options[:ir]
          set_parameter :AutoPowerOff, options[:apo]
          set_parameter :BeepMode, options[:beep]
        end

        # Set common options for all shooting modes
        def get_common_options
          get_parameter_and_show :ZoomSetting
          get_parameter_and_show :FocusMode
          get_parameter_and_show :ExposureMode
          get_parameter_and_show :ExposureCompensation
          get_parameter_and_show :FNumber
          get_parameter_and_show :ShutterSpeed
          get_parameter_and_show :IsoSpeedRate
          get_parameter_and_show :WhiteBalance
          get_parameter_and_show :SceneSelection
          get_parameter_and_show :FlipSetting
          get_parameter_and_show :TvColorSystem
          get_parameter_and_show :InfraredRemoteControl
          get_parameter_and_show :AutoPowerOff
          get_parameter_and_show :BeepMode
        end

        # Set common options for still/intervalstill shooting modes
        def set_still_common_options
          set_parameter :TrackingFocus, options[:track]
          set_parameter :SelfTimer, options[:self]
          set_parameter :FlashMode, options[:flash]
          if options[:aspect] && options[:size]
            set_parameter :StillSize, aspect: options[:aspect], size: options[:size]
          end
          set_parameter :StillQuality, options[:quality]
          set_parameter :PostviewImageSize, options[:postview]
          set_parameter :ViewAngle, options[:angle]
        end

        # Get common options for still/intervalstill shooting modes
        def get_still_common_options
          get_parameter_and_show :TrackingFocus
          get_parameter_and_show :SelfTimer
          get_parameter_and_show :FlashMode
          get_parameter_and_show :StillSize
          get_parameter_and_show :StillQuality
          get_parameter_and_show :PostviewImageSize
          get_parameter_and_show :ViewAngle
        end

        # Set common options for movie/looprec shooting modes
        def set_movie_common_options
          set_parameter :MovieFileFormat, options[:format]
          set_parameter :MovieQuality, options[:quality]
          set_parameter :SteadyMode, options[:steady]
          set_parameter :ColorSetting, options[:color]
          set_parameter :WindNoiseReduction, options[:noise]
          set_parameter :AudioRecording, options[:audio]
        end

        # Get common options for movie/looprec shooting modes
        def get_movie_common_options
          get_parameter_and_show :MovieFileFormat
          get_parameter_and_show :MovieQuality
          get_parameter_and_show :SteadyMode
          get_parameter_and_show :ColorSetting
          get_parameter_and_show :WindNoiseReduction
          get_parameter_and_show :AudioRecording
        end
      end

      #----------------------------------------COMMAND OPTIONS----------------------------------------

      # Common options for all shooting modes
      def self.common_options
        option :zoom, type: :numeric, desc: 'Zoom position (0-99)', banner: 'POSITION'
        option :zoom_mode, type: :string, desc: 'Zoom setting', banner: 'MODE'
        option :focus_mode, type: :string, desc: 'Focus mode', banner: 'MODE'
        option :exposure, type: :string, desc: 'Exposure mode', banner: 'MODE'
        option :ev, type: :string, desc: 'Exposure compensation', banner: 'EV'
        option :fnum, type: :string, desc: 'F number', banner: 'NUM'
        option :shutter, type: :string, desc: 'Shutter speed', banner: 'NSEC'
        option :iso, type: :string, desc: 'ISO speed rate', banner: 'NUM'
        option :wb, type: :string, desc: 'White balance mode', banner: 'MODE'
        option :temp, type: :numeric, desc: 'Color temperature', banner: 'K'
        option :scene, type: :string, desc: 'Scene selection', banner: 'MODE'
        option :flip, type: :string, desc: 'Flip', banner: 'MODE'
        option :tv, type: :string, desc: 'TV color system', banner: 'MODE'
        option :ir, type: :string, desc: 'IR remote control', banner: 'MODE'
        option :apo, type: :string, desc: 'Auto power off', banner: 'MODE'
        option :beep, type: :string, desc: 'Beep mode', banner: 'MODE'
      end

      # Common options for still/intervalstill shooting modes
      def self.still_common_options
        option :track, type: :string, desc: 'Tracking focus', banner: 'MODE'
        option :self, type: :numeric, desc: 'Self timer', banner: 'NSEC'
        option :flash, type: :string, desc: 'Flash mode', banner: 'MODE'
        option :size, type: :string, desc: 'Still size', banner: 'PIXEL'
        option :aspect, type: :string, desc: 'Still aspect', banner: 'MODE'
        option :quality, type: :string, desc: 'Still quality', banner: 'MODE'
        option :postview, type: :string, desc: 'Postview image size', banner: 'PIXEL'
        option :angle, type: :numeric, desc: 'View angle', banner: 'DEGREE'
      end

      # Common options for movie/looprec shooting modes
      def self.movie_common_options
        option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
        option :format, type: :string, desc: 'Movie Format', banner: 'MODE'
        option :quality, type: :string, desc: 'Movie Quality', banner: 'MODE'
        option :steady, type: :string, desc: 'Steady Mode', banner: 'MODE'
        option :color, type: :string, desc: 'Color setting', banner: 'MODE'
        option :noise, type: :string, desc: 'Wind noise reduction', banner: 'MODE'
        option :audio, type: :string, desc: 'Audio recording', banner: 'MODE'
      end


      #----------------------------------------COMMAND DEFINITIONS----------------------------------------

      desc 'still [options]', 'Capture still images'
      option :interval, type: :numeric, desc: 'Interval of capturing (sec)', banner: 'NSEC'
      option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
      still_common_options
      common_options
      option :transfer, type: :boolean, desc: 'Transfer postview image', default: true
      def still
        init_camera
        @cam.change_function_to_shoot 'still', 'Single'

        # Set/Get options
        set_still_common_options
        set_common_options
        if options[:setting]
          get_still_common_options
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        # Interval option resembles Intervalrec shooting mode.
        # The advantage is that we can transfer captured stills each time, meanwhile Intervalrec shooting mode cannot.
        # However, the interval time tends to be longer than that of Intervalrec mode.
        if options[:interval]
          if options[:output]
            # Generate sequencial filenames based on --output option
            generator = generate_sequencial_filenames options[:output], 'JPG'
          end

          # Capture forever until trapped by SIGINT
          trapped = false
          trap(:INT) { trapped = true }
          puts "Capturing stills by #{options[:interval]} sec. Type C-c (SIGINT) to quit capturing."
          start_time = Time.now
          loop do
            loop_start = Time.now
            if options[:output]
              @cam.capture_still filename: generator.next, transfer: options[:transfer]
            else
              @cam.capture_still transfer: options[:transfer]
            end
            if trapped
              puts 'Trapped!'
              break
            end
            loop_end = Time.now
            # If total time exceeds, quit capturing.
            if options[:time] && options[:time] < loop_end - start_time
              puts 'Time expired!'
              break
            end
            # Wait until specified interval elapses
            elapsed = loop_end - loop_start
            if options[:interval] - elapsed > 0
              sleep(options[:interval] - elapsed)
            end
          end
          trap(:INT, 'DEFAULT')
        else
          @cam.capture_still filename: options[:output], transfer: options[:transfer]
        end
        finalize
      end


      desc 'cont [options]', 'Capture still images continuously'
      option :mode, type: :string, desc: 'Continuous shooting mode', banner: 'MODE', default: 'Single'
      option :speed, type: :string, desc: 'Continuous shooting speed', banner: 'MODE'
      option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
      still_common_options
      common_options
      option :transfer, type: :boolean, desc: 'Transfer postview image', default: false
      def cont
        init_camera
        unless @cam.support_group? :ContShootingMode
          puts 'This camera does not support continuous shooting mode. Exiting...'
          exit 1
        end
        @cam.change_function_to_shoot('still', options[:mode])

        # Set/Get options
        set_parameter :ContShootingMode, options[:mode]
        set_parameter :ContShootingSpeed, options[:speed]
        set_still_common_options
        set_common_options
        if options[:setting]
          get_parameter_and_show :ContShootingMode
          # ContShootingSpeed API will fail when ContShootingMode = 'Single'
          get_parameter_and_show :ContShootingSpeed
          get_still_common_options
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        case options[:mode]
          when 'Single', 'MotionShot', 'Burst'
            @cam.capture_still filename: options[:output], transfer: options[:transfer]
          when 'Continuous', 'Spd Priority Cont.'
            @cam.start_continuous_shooting
            if options[:time]
              sleep options[:time]
              puts 'Time expired!'
            else
              # Continue forever until trapped by SIGINT
              trapped = false
              trap(:INT) { trapped = true }
              puts 'Type C-c (SIGINT) to quit recording.'
              loop do
                break if trapped
                sleep 0.1
              end
              puts 'Trapped!'
              trap(:INT, 'DEFAULT')
            end
            @cam.stop_continuous_shooting prefix: options[:output], transfer: options[:transfer]
        end
        finalize
      end


      desc 'movie [options]', 'Record movies'
      option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
      movie_common_options
      common_options
      option :transfer, type: :boolean, desc: 'Transfer recorded movie immediately'
      def movie
        init_camera
        @cam.change_function_to_shoot('movie')

        # Set/Get options
        set_movie_common_options
        set_common_options
        if options[:setting]
          get_movie_common_options
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        @cam.start_movie_recording
        if options[:time]
          sleep options[:time]
          puts 'Time expired!'
        else
          # record forever until trapped by SIGINT
          trapped = false
          trap(:INT) { trapped = true }
          puts 'Type C-c (SIGINT) to quit recording.'
          loop do
            break if trapped
            sleep 0.1
          end
          puts 'Trapped!'
          trap(:INT, 'DEFAULT')
        end
        @cam.stop_movie_recording filename: options[:output], transfer: options[:transfer]
        finalize
      end


      desc 'intrec [options]', 'Do interval recording'
      option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
      option :interval, type: :string, desc: 'Interval (sec)', banner: 'NSEC'
      still_common_options
      common_options
      option :transfer, type: :boolean, desc: 'Transfer selected contents '
      def intrec
        init_camera
        @cam.change_function_to_shoot('intervalstill')

        # Set/Get options
        set_parameter :IntervalTime, options[:interval]
        set_still_common_options
        set_common_options
        if options[:setting]
          get_parameter_and_show :IntervalTime
          get_still_common_options
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        @cam.start_interval_recording
        if options[:time]
          sleep options[:time]
          puts 'Time expired!'
        else
          # continue forever until trapped by SIGINT
          trapped = false
          trap(:INT) { trapped = true }
          puts 'Type C-c (SIGINT) to quit recording.'
          loop do
            break if trapped
            sleep 0.1
          end
          puts 'Trapped!'
          trap(:INT, 'DEFAULT')
        end
        @cam.stop_interval_recording transfer: options[:transfer]
        finalize
      end


      desc 'looprec [options]', 'Do loop recording'
      option :time, type: :numeric, desc: 'Recording time (min)', banner: 'NMIN'
      option :loop_time, type: :string, desc: 'Loop recording time (min)', banner: 'NMIN'
      movie_common_options
      common_options
      option :transfer, type: :boolean, desc: 'Transfer selected contents '
      def looprec
        init_camera
        @cam.change_function_to_shoot('looprec')

        # Set/Get options
        set_parameter :LoopRecTime, options[:loop_time]
        set_movie_common_options
        set_common_options
        if options[:setting]
          get_parameter_and_show :LoopRecTime
          get_movie_common_options
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        @cam.start_loop_recording
        if options[:time]
          sleep(options[:time] * 60)
          puts 'Time expired!'
        else
          # record forever until trapped by SIGINT
          trapped = false
          trap(:INT) { trapped = true }
          puts 'Type C-c (SIGINT) to quit recording.'
          loop do
            break if trapped
            sleep 0.1
          end
          puts 'Trapped!'
          trap(:INT, 'DEFAULT')
        end
        @cam.stop_loop_recording filename: options[:output], transfer: options[:transfer]
        finalize
      end


      desc 'liveview [options]', 'Stream liveview images'
      option :time, type: :numeric, desc: 'Recording time (sec)', banner: 'NSEC'
      option :size, type: :string, desc: 'Liveview size', banner: 'SIZE'
      common_options
      def liveview
        init_camera
        # Set/Get options
        set_common_options
        if options[:setting]
          get_parameter_and_show :LiveviewSize
          get_common_options
          return
        end

        @cam.act_zoom absolute: options[:zoom]

        th = @cam.start_liveview_thread(time: options[:time], size: options[:size]) do |img, info|
          filename = "#{img.sequence_number}.jpg"
          File.write filename, img.jpeg_data
          puts "Wrote: #{filename}."
        end
        trap(:INT) { th.kill }
        puts 'Liveview download started. Type C-c (SIGINT) to quit.'
        th.join
        trap(:INT, 'DEFAULT')
        puts 'Finished.'
        finalize
      end


      desc 'contents [options]', 'List contents and transfer them from camera storage'
      option :type, type: :array, desc: 'Contents types (still/movie_mp4/movie_xavcs)', default: nil
      option :datelist, type: :boolean, desc: 'List Dates and number of contents'
      option :date, type: :string, desc: 'Date (yyyyMMdd)'
      option :sort, type: :string, desc: 'Sorting order [ascend/descend]', default: 'descending'
      option :count, type: :numeric, desc: 'Number of contents'
      option :transfer, type: :boolean, desc: 'Transfer selected contents'
      option :delete, type: :boolean, desc: 'Delete contents'
      def contents
        init_camera
        @cam.change_function_to_transfer

        puts 'Retrieving...'
        if options[:datelist]
          dates = @cam.get_date_list date_count: options[:count]
          num_contents = dates.map { |d, c| c }.inject(:+)
          puts "#{dates.size} date folders / #{num_contents} contents found."
          puts "Dates\t\tN-Contents"
          dates.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          return
        end

        if options[:date]
          contents = @cam.get_content_list type: options[:type], date: options[:date], sort: options[:sort], count: options[:count]
        else
          contents = @cam.get_content_list type: options[:type], sort: options[:sort], count: options[:count]
        end

        if contents.blank?
          puts 'No contents!'
        else
          puts "#{contents.size} contents found."
          puts "File name\t\tKind\t\tCreated time\t\tURL"
          contents.each do |c|
            filename = c['content']['original'][0]['fileName']
            kind = c['contentKind']
            ctime = c['createdTime']
            url = c['content']['original'][0]['url']
            puts "#{filename}\t\t#{kind}\t\t#{ctime}\t\t#{url}"
          end
          if options[:transfer]
            @cam.transfer_contents contents
          end
          if options[:delete]
            answer = $terminal.ask('All contents listed above are deleted. Continue? [y/N]') { |q| q.validate = /[yn]/i; q.default = 'n' }
            @cam.delete_contents contents if answer == 'y'
          end
        end
        finalize
      end

    end
  end
end
