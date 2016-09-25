require 'sony_camera_remote_api/version'
require 'sony_camera_remote_api/logging'
require 'sony_camera_remote_api/ssdp'
require 'sony_camera_remote_api/utils'
require 'sony_camera_remote_api/camera_api'
require 'sony_camera_remote_api/packet'
require 'core_ext/hash_patch'
require 'httpclient'
require 'active_support'
require 'active_support/core_ext'
require 'benchmark'
require 'forwardable'


module SonyCameraRemoteAPI

  # Top-level class providing wrapper methods of Sony Camera Remote APIs.
  class Camera
    extend Forwardable
    include Logging
    include SSDP
    include Utils

    def_delegators :@api_manager, :apis, :method_missing, :getEvent, :getAvailableApiList,
                   :wait_event,
                   :get_parameter, :get_parameter!, :set_parameter, :set_parameter!, :get_current, :get_current!,
                   :support?, :support_group?

    attr_reader :endpoints

    # Timeout for saving images captured by continous shooting.
    CONT_SHOOT_SAVING_TIME = 25
    # Timeout for focusing by tracking focus.
    TRACKING_FOCUS_TIMEOUT = 4


    # Creates a new Camera object.
    # @note It is good idea to save endpoint URLs by each cameras somewhere to omit SSDP search.
    # @param [Hash] endpoints     Endpoint URLs. if not given, SSDP search is executed.
    # @param [Proc] reconnect_by  Hook method called when Wi-Fi is disconnected.
    # @param [String, IO, Array<String, IO>] log_file   file name or stream to output log.
    # @param [Boolean] finalize   If true, stopRecMode API is called in the destructor.
    #   As far as I know, we don't have any trouble even if we never call stopRecMode.
    def initialize(endpoints: nil, reconnect_by: nil, log_file: $stdout, log_level: Logger::INFO, finalize: false)
      set_output log_file
      set_level  log_level
      @endpoints = endpoints || ssdp_search
      @reconnect_by = reconnect_by
      @api_manager = CameraAPIManager.new @endpoints, reconnect_by: @reconnect_by
      @cli = HTTPClient.new
      @cli.connect_timeout  = @cli.send_timeout = @cli.receive_timeout = 30

      # Some cameras which use "Smart Remote Control" app must call this method before remote shooting.
      startRecMode! timeout: 0

      # As far as I know, we don't have to call stopRecMode method
      # It may be useful for power-saving because stopRecMode leads to stop liveview.
      if finalize
        ObjectSpace.define_finalizer(self, self.class.finalize(self))
      end
    end

    # Destructor
    def self.finalize(this)
      proc do
        this.stopRecMode!
        this.log.info 'Finished remote shooting function.'
      end
    end


    # Change camera function to 'Remote Shooting' and then set shooting mode.
    # @param [String] mode  Shoot mode
    # @param [String] cont  Continous shooting mode (only available when shoot mode is 'still')
    # @return [void]
    # @see 'Shoot mode parameters' in API reference
    # @see 'Continuous shooting mode parameter' in API reference
    def change_function_to_shoot(mode, cont = nil)
      # cameras that does not support CameraFunction API group has only 'Remote Shooting' function
      set_parameter! :CameraFunction, 'Remote Shooting'
      set_parameter :ShootMode, mode
      if mode == 'still' && cont
        set_parameter! :ContShootingMode, cont
      end
    end


    # Change camera function to 'Contents Transfer'.
    # You should call this method before using contents-retrieving methods, which are following 4 methods:
    # * get_content_list
    # * get_date_list
    # * transfer_contents
    # * delete_contents
    # @return [void]
    def change_function_to_transfer
      set_parameter :CameraFunction, 'Contents Transfer'
    end


    # Capture still image(s) and transfer them to local storage.
    # @note You have to set shooting mode to 'still' before calling this method.
    #   This method can be used in following continuous-shooting mode if supported:
    #   * Single     : take a single picture
    #   * Burst      : take 10 pictures at a time
    #   * MotionShot : take 10 pictures and render the movement into a single picture
    # @param [Boolean]  transfer  Flag to transfer the postview image.
    # @param [String]   filename  Name of image file to be transferred. If not given, original name is used.
    #    Only available in Single/MotionShot shooting mode.
    # @param [String]   prefix    Prefix of sequencial image files to be transferred. If not given, original name is used.
    #    Only available in Burst shooting mode.
    # @param [String]   dir       Directory where image file is saved. If not given, current directory is used.
    # @return [String, Array<String>, nil]  Filename of the transferred image(s). If 'transfer' is false, returns nil.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Capture a single still image, and then save it as images/TEST.JPG.
    #   cam.change_function_to_shoot 'still', 'Single'
    #   cam.capture_still filename: 'TEST.JPG', dir: 'images'
    #
    #   # Capture 10 images by burst shooting and save them as 'TEST_0.jpg', ... 'TEST_9.jpg'.
    #   cam.change_function_to_shoot 'still', 'Burst'
    #   cam.capture_still prefix: 'TEST'
    def capture_still(transfer: true, filename: nil, prefix: nil, dir: nil)
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      log.info 'Capturing...'
      postview_url = ''
      time = Benchmark.realtime do
        postview_url = actTakePicture.result[0][0]
        wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      end

      log.debug postview_url
      log.info 'Capture finished. (%.2f sec)' % [time]

      if transfer
        case get_current!(:ContShootingMode)
          when 'Burst'
            transferred = transfer_in_burst_mode postview_url, prefix: prefix, dir: dir
          else
            filename = File.basename(URI.parse(postview_url).path) if filename.nil?
            transferred = transfer_postview(postview_url, filename, dir: dir)
        end
        transferred
      end
    end


    # Start continuous shooting.
    # To stop shooting, call stop_continuous_shooting method.
    # @note You have to set shooting mode to 'still' and continuous shooting mode to following modes:
    #   * Continuous          : take pictures continuously until stopped.
    #   * Spd Priority Cont.  : take pictures continuously at a rate faster than 'Continuous'.
    # @return [void]
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Start continuous shooting and transfer all images.
    #   cam.change_function_to_shoot('still', 'Continuous')
    #   cam.start_continuous_shooting
    #   ...
    #   cam.stop_continuous_shooting(transfer: true)
    def start_continuous_shooting
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      startContShooting
      wait_event { |r| r[1]['cameraStatus'] == 'StillCapturing' }
      log.info 'Started continous shooting.'
    end


    # Stop continuous shooting and transfers all still images.
    # @note 'transfer' flag is set false as default, because transfer time is prone to be much longer.
    # @param [Boolean]  transfer  Flag to transfer the captured images.
    # @param [String]   prefix    Prefix of of sequencial image files to be transferred. If not given, original name is used.
    # @param [String]   dir       Directory where image file is saved. If not given, current directory is used.
    # @return [Array<String>, nil]  List of filenames of the transferred images. If 'transfer' is false, returns nil.
    def stop_continuous_shooting(transfer: false, prefix: nil, dir: nil)
      stopContShooting
      log.info 'Stopped continuous shooting: saving...'
      urls_result = wait_event(timeout: CONT_SHOOT_SAVING_TIME) { |r| r[40].present? }
      urls = urls_result[40]['contShootingUrl'].map { |e| e['postviewUrl'] }
      log.debug 'Got URLs.'
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      log.info "Saving finished: #{urls.size} images."
      if transfer
        gen = generate_sequencial_filenames prefix, 'JPG' if prefix.present?
        transferred = []
        urls.each do |url|
          if prefix.present?
            filename = gen.next
          else
            filename = File.basename(URI.parse(url).path)
          end
          result = transfer_postview(url, filename, dir: dir)
          # If transfer failed, it is possible that Wi-Fi is disconnected,
          # that means subsequent postview images become unavailable.
          break if result.nil?
          transferred << result
        end
        transferred.compact
      end
    end


    # Start movie recording.
    # To stop recording, call stop_movie_recording method.
    # @note You have to set shooting mode to 'movie' before calling this method.
    # @return [void]
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Record movie and transfer it.
    #   cam.change_function_to_shoot('movie')
    #   cam.start_movie_recording
    #   ...
    #   cam.stop_movie_recording(transfer: true)
    def start_movie_recording
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      startMovieRec
      wait_event { |r| r[1]['cameraStatus'] == 'MovieRecording' }
      log.info 'Started movie recording.'
    end


    # Stop movie recording and transfers the movie file.
    # @note 'transfer' flag is set false as default, because transfer time is prone to be much longer.
    # @param [Boolean]  transfer  Flag to transfer the recorded movie file.
    # @param [String]   filename  Name of the movie file to be transferred. If not given, original name is used.
    # @param [String]   dir       Directory where image file is saved. If not given, current directory is used.
    # @return [String, nil]            Filename of the transferred movie. If 'transfer' is false, returns nil.
    def stop_movie_recording(transfer: false, filename: nil, dir: nil)
      stopMovieRec
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      log.info 'Stopped movie recording.'
      if transfer
        transfer_recorded_movie(filename: filename, dir: dir)
      end
    end


    # Start interval still recording (a.k.a Timelapse).
    # To stop recording, call stop_interval_recording method.
    # @note You have to set shooting mode to 'intervalstill' before calling this method.
    # @return [void]
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Start interval still recording (does not transfer).
    #   cam.change_function_to_shoot('intervalstill')
    #   cam.start_interval_recording
    #   ...
    #   cam.stop_interval_recording
    def start_interval_recording
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      startIntervalStillRec
      wait_event { |r| r[1]['cameraStatus'] == 'IntervalRecording' }
      log.info 'Started interval still recording.'
    end


    # Stop interval still recording and transfers all still images.
    # @note 'transfer' flag is set false as default, because transfer time is prone to be much longer.
    # @param [Boolean]  transfer  Flag to transfer still images
    # @param [String]   prefix    Prefix of sequencial image files to be transferred. If not given, original name is used.
    # @param [String]   dir       Directory where image file is saved. If not given, current directory is used.
    # @return [Array<String>, nil]  List of filenames of the transferred images. If 'transfer' is false, returns nil.
    def stop_interval_recording(transfer: false, prefix: nil, dir: nil)
      stopIntervalStillRec
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      num_shots = getEvent([false]).result[58]['numberOfShots']
      log.info "Stopped interval still recording: #{num_shots} images."
      if transfer
        transfer_interval_stills num_shots, prefix: prefix, dir: dir
      end
    end


    # Start loop recording.
    # To stop recording, call stop_loop_recording method.
    # @note You have to set shooting mode to 'looprec' before calling this method.
    # @return [void]
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Start loop movie recording (does not transfer).
    #   cam.change_function_to_shoot('looprec')
    #   cam.start_loop_recording
    #   ...
    #   cam.stop_loop_recording
    def start_loop_recording
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      startLoopRec
      wait_event { |r| r[1]['cameraStatus'] == 'LoopRecording' }
      log.info 'Started loop recording.'
    end


    # Stop loop recording and transfers the movie file.
    # @note 'transfer' flag is set false as default, because transfer time is prone to be much longer.
    # @param [Boolean]  transfer  Flag to transfer the recorded movie file
    # @param [String]   filename  Name of the movie file to be transferred. If not given, original name is used.
    # @param [String]   dir       Directory where image file is saved. If not given, current directory is used.
    # @return [String, nil]       Filename of the transferred movie. If 'transfer' is false, returns nil.
    def stop_loop_recording(transfer: false, filename: nil, dir: nil)
      stopLoopRec
      wait_event { |r| r[1]['cameraStatus'] == 'IDLE' }
      log.info 'Stopped loop recording.'
      if transfer
        transfer_recorded_movie(filename: filename, dir: dir)
      end
    end


    # Act zoom.
    # Zoom position can be specified by relative and absolute percentage within the range of 0-100.
    # If Both option are specified, absolute position is preceded.
    # @param [Fixnum] absolute    Absolute position of the lense. 0 is the Wide-end and 100 is the Tele-end.
    # @param [Fixnum] relative    Relative percecntage to current position of the lense.
    # @return [Array<Fixnum>]     Array of initial zoom position and current zoom position.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.act_zoom(absolute: 0)     # zoom out to the wide-end
    #   cam.act_zoom(absolute: 100)   # zoom in to the tele-end
    #   cam.act_zoom(relative: -50)   # zoom out by -50 from the current position
    def act_zoom(absolute: nil, relative: nil)
      # Check arguments
      return if [relative, absolute].none?
      relative = nil if [relative, absolute].all?

      # Get current position
      initial = getEvent(false).result[2]['zoomPosition']
      unless initial.between? 0, 100
        initial = wait_event { |r| r[2]['zoomPosition'].between? 0, 100 }[2]['zoomPosition']
      end
      # Return curent position if relative is 0
      return initial if relative == 0

      # Calculate target positions
      if relative
        absolute = [[initial + relative, 100].min, 0].max
      else
        absolute = [[absolute, 100].min, 0].max
      end
      relative = absolute - initial
      current = initial

      log.debug "Zoom started: #{initial} -> #{absolute} (relative: #{relative})"

      # If absolute position is wide or tele end, use only long push zoom.
      if [0, 100].include? absolute
        current = zoom_until_end absolute
      else
        # Otherwise, use both long push and 1shot zoom by relative position
        current, rest = zoom_by_long_push current, relative
        current, _    = zoom_by_1shot current, rest
      end

      log.debug "Zoom finished: #{initial} -> #{current} (target was #{absolute})"
      [initial, current]
    end


    # Do focus, which is the same as half-pressing the shutter button.
    # @return [Boolean] +true+ if focus succeeded, +false+ if failed.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Focus function is available only 'still' shoot mode
    #   cam.change_function_to_shoot 'still'
    #   # Capture forever only when focus succeeded.
    #   loop do
    #     if cam.act_focus
    #       cam.capture_still
    #     end
    #   end
    def act_focus
      return false unless support? :actHalfPressShutter
      cancel_focus
      actHalfPressShutter
      rsp = wait_event { |r| ['Focused', 'Failed'].include? r[35]['focusStatus'] }
      if rsp[35]['focusStatus'] =='Focused'
        log.info 'Focused.'
        true
      elsif rsp[35]['focusStatus'] =='Failed'
        log.info 'Focuse failed!'
        cancelHalfPressShutter
        wait_event { |r| r[35]['focusStatus'] == 'Not Focusing' }
        false
      end
    end


    # Do touch focus, by which we can specify the focus position.
    # @note Tracking focus and Touch focus is exclusive function.
    #   Tracking focus is disabled automatically by calling this method.
    # @param [Fixnum] x   Percentage of X-axis position.
    # @param [Fixnum] y   Percentage of Y-axis position.
    # @return [Boolean]   AFType ('Touch' or 'Wide') if focus succeeded. nil if failed.
    # @see Touch AF position parameter in API reference
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   # Try to focus on upper-middle position.
    #   if cam.act_touch_focus(50, 10)
    #     cam.capture_still
    #   end
    def act_touch_focus(x, y)
      return false unless support? :setTouchAFPosition
      set_parameter! :TrackingFocus, 'Off'
      cancel_focus

      x = [[x, 100].min, 0].max
      y = [[y, 100].min, 0].max
      result = setTouchAFPosition([x, y]).result
      if result[1]['AFResult'] == true
        log.info "Touch focus (#{x}, #{y}) OK."
        # result[1]['AFType']
        true
      else
        log.info "Touch focus (#{x}, #{y}) failed."
        false
      end
    end


    # Do tracking focus, by which the focus position automatically track the object.
    # The focus position is expressed by percentage to the origin of coordinates, which is upper left of liveview images.
    # @param [Fixnum] x   Percentage of X-axis position.
    # @param [Fixnum] y   Percentage of Y-axis position.
    # @return [Boolean] +true+ if focus succeeded, +false+ if failed.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still'
    #   # Start tracking focus from the center position
    #   if cam.act_tracking_focus(50, 50)
    #     th = cam.start_liveview_thread do |img, info|
    #       info.frames.each do |f|
    #         # Get tracking focus position from the liveview frame info
    #         puts "top-left:     (#{f.top_left.x}, #{f.top_left.y})"
    #         puts "bottom-right: (#{f.bottom_right.x}, #{f.bottom_right.y})"
    #       end
    #     end
    #     th.join
    #   end
    def act_tracking_focus(x, y)
      return false unless support_group? :TrackingFocus
      set_parameter :TrackingFocus, 'On'
      cancel_focus

      x = [[x, 100].min, 0].max
      y = [[y, 100].min, 0].max
      actTrackingFocus(['xPosition': x, 'yPosition': y]).result
      begin
        wait_event(timeout: TRACKING_FOCUS_TIMEOUT) { |r| r[54]['trackingFocusStatus'] == 'Tracking' }
        log.info "Tracking focus (#{x}, #{y}) OK."
        true
      rescue EventTimeoutError => e
        log.info "Tracking focus (#{x}, #{y}) Failed."
        false
      end
    end


    # Return whether the camera has focused or not.
    # @return [Boolean] +true+ if focused, +false+ otherwise.
    # @see act_focus
    # @see act_touch_focus
    def focused?
      result = getEvent(false).result
      result[35] && result[35]['focusStatus'] == 'Focused'
    end


    # Return whether the camera is tracking an object for tracking focus.
    # @return [Boolean] +true+ if focused, +false+ otherwise.
    # @see act_tracking_focus
    def tracking?
      result = getEvent(false).result
      result[54] && result[54]['trackingFocusStatus'] == 'Tracking'
    end


    # Cancel focus If camera has been focused.
    # @return [void]
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #   # Try to focus on upper-middle position.
    #   if cam.act_tracking_focus(50, 10)
    #     puts cam.focused?
    #     cam.capture_still
    #     puts cam.focused?
    #   end
    def cancel_focus
      result = getEvent(false).result
      # Canceling tracking/touch focus should be preceded for half-press
      if result[54] && result[54]['trackingFocusStatus'] == 'Tracking'
        cancelTrackingFocus
        rsp = wait_event { |r| r[54]['trackingFocusStatus'] == 'Not Tracking' }
      end
      if result[34] && result[34]['currentSet'] == true
        cancelTouchAFPosition
        rsp = wait_event { |r| r[34]['currentSet'] == false }
      end
      if result[35] && result[35]['focusStatus'] != 'Not Focusing'
        cancelHalfPressShutter
        rsp = wait_event { |r| r[35]['focusStatus'] == 'Not Focusing' }
      end
    end



    # Starts a new thread that downloads streamed liveview images.
    # This liveview thread continues downloading unless the one of the following conditions meets:
    # The both hook method is called called each time after a liveview image or frame is downloaded.
    # @param [String] size  The liveview size.
    # @param [Fixnum] time  Time in seconds until finishing liveview streaming.
    # @yield [LiveviewImage, LiveviewFrameInformation] The block called every time a liveview image is downloaded.
    # @yieldparam [LiveviewImage] liveview image of each frame.
    # @yieldparam [LiveviewFrameInformation] liveview frame information of each frame.
    #   If liveview frame information is not supported, nil is always given.
    # @return [Thread] liveview downloading thread object
    def start_liveview_thread(size: nil, time: nil)
      liveview_url, frame_info_enabled = init_liveview size: size
      log.debug "liveview URL: #{liveview_url}"

      th = Thread.new do
        thread_start = loop_end = Time.now
        count = 0
        buffer = ''
        frame_info= nil
        # Ensure to finalize if the thread is killed
        begin
          # Break from loop inside when timeout
          catch :finished do
            # For reconnection
            reconnect_and_retry_forever do
              # Retrieve streaming data
              @cli.get_content(liveview_url) do |chunk|
                loop_start = Time.now
                received_sec = loop_start - loop_end

                buffer << chunk
                log.debug "start--------------------buffer.size=#{buffer.size}, #{format("%.2f", received_sec * 1000)} ms"
                begin
                  obj = LiveviewPacket.read(buffer)
                rescue EOFError => e
                  # Simply read more data
                rescue IOError, BinData::ValidityError => e
                  # Clear buffer and read data again
                  buffer = ''
                else
                  # Received an packet successfully!
                  case obj.payload_type
                    when 0x01
                      # When payload is jpeg data
                      log.debug "  sequence  : #{obj.sequence_number}"
                      log.debug "  data_size : #{obj.payload.payload_data_size_wo_padding}"
                      log.debug "  pad_size  : #{obj.payload.padding_size}"
                      if frame_info_enabled && frame_info.nil?
                        log.debug 'frame info is not present. skipping...'
                      else
                        block_time = Benchmark.realtime do
                          yield(LiveviewImage.new(obj), frame_info)
                        end
                        log.debug "block time     : #{format('%.2f', block_time*1000)} ms."
                      end
                      count += 1
                    when 0x02
                      # When payload is liveview frame information
                      log.debug "frame count = #{obj.payload.frame_count}"
                      if obj.payload.frame_count > 0
                        obj.payload.frame_data.each do |d|
                          log.debug "  category     : #{d.category}"
                          log.debug "  status       : #{d.status}, #{d.additional_status}"
                          log.debug "  top-left     : #{d.top_left.x}, #{d.top_left.y}"
                          log.debug "  bottom-right : #{d.bottom_right.x}, #{d.bottom_right.y}"
                        end
                      end
                      # Keep until next liveview image comes.
                      frame_info = LiveviewFrameInformation.new obj
                  end

                  last_loop_end = loop_end
                  loop_end = Time.now
                  loop_elapsed = loop_end - last_loop_end
                  log.debug "end----------------------#{format("%.2f", loop_elapsed * 1000)} ms, #{format("%.2f", 1 / loop_elapsed)} fps"

                  # Delete the packet data from buffer
                  buffer = buffer[obj.num_bytes..-1]

                  # Finish if time exceeds total elapsed time
                  throw :finished if time && (loop_end - thread_start > time)
                end
              end
            end
          end
        ensure
          # Comes here when liveview finished or killed by signal
          puts 'Stopping Liveview...'
          stopLiveview
          total_time = Time.now - thread_start
          log.info 'Liveview thread finished.'
          log.debug "  total time: #{format('%d', total_time)} sec"
          log.debug "  count: #{format('%d', count)} frames"
          log.debug "  rate: #{format('%.2f', count/total_time)} fps"
        end
      end
      th
    end


    # Get a list of content information.
    # Content information is Hash object that contains URI, file name, timestamp and other informations.
    # You can transfer contents by calling 'transfer_contents' method with the content information Hash.
    # This is basically the wrapper of getContentList API. For more information about request/response, see API reference.
    # @note You have to set camera function to 'Contents Transfer' before calling this method.
    # @param [String, Array<String>] type Same as 'type' request parameter of getContentList API.
    # @param [Boolean] date   Date in format of 'YYYYMMDD' used in date-view. If not specified, flat-view is used.
    # @param [String] sort    Same as 'sort' request parameter of getContentList API.
    # @param [Fixnum] count   Number of contents to get.
    #   Unlike the one of request parameter of getContentList API, you can specify over 100.
    # @return [Array<Hash>]   Content informations
    # @see getContentList API in the API reference.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_transfer
    #
    #   # Get all contents
    #   contents = cam.get_content_list
    #   # Get still contents created on 2016/8/1
    #   contents = cam.get_content_list(type: 'still', date: '20160801')
    #   # Get 3 oldest movie contents
    #   contents = cam.get_content_list(type: ['movie_xavcs', 'movie_mp4'], sort: 'ascending', count: 3)
    #
    #   # Get filenames and URL of each content
    #   contents.each |c| do
    #     filename = c['content']['original'][0]['fileName']
    #     url = c['content']['original'][0]['url']
    #     puts "#{filename}, #{url}"
    #   end
    #
    #   # Transfer contents
    #   transfer_contents(contents)
    def get_content_list(type: nil, date: nil, sort: 'descending', count: nil)
      type = Array(type) if type.is_a? String

      scheme = getSchemeList.result[0][0]['scheme']
      source = getSourceList([{'scheme' => scheme}]).result[0][0]['source']

      if date
        date_found, cnt = get_date_list.find { |d| d[0]['title'] == date }
        if date_found
          contents = get_content_list_sub date_found['uri'], type: type, view: 'date', sort: sort, count: count
        else
          log.error "Cannot find any contents at date '#{date}'!"
          return []
        end
      else
        # type option is available ONLY FOR 'date' view.
        if type.present?
          # if 'type' option is specified, call getContentList with date view for every date.
          # this is because getContentList with flat view is extremely slow as a number of contents grows.
          dates_counts = get_date_list type: type, sort: sort
          contents = []
          if count.present?
            dates_counts.each do |date, cnt_of_date|
              num = [cnt_of_date, count - contents.size].min
              contents += get_content_list_sub date['uri'], type: type, view: 'date', sort: sort, count: num
              break if contents.size >= count
            end
            # it is no problem that a number of contents is less than count
            contents = contents[0, count]
          else
            dates_counts.each do |date, cnt_of_date|
              contents += get_content_list_sub date['uri'], type: type, view: 'date', sort: sort, count: cnt_of_date
            end
          end
        else
          # contents = get_content_list_sub source, view: 'flat', sort: sort, count: count
          contents = get_content_list_sub source, view: 'flat', sort: sort, count: count
        end
      end
      contents
    end


    # Gets a list of dates and the number of contents of each date.
    # This is basically the wrapper of getContentList API. For more information about request/response, see API reference.
    # @note You have to set camera function to 'Contents Transfer' before calling this method.
    # @param [String, Array<String>] type   Same as 'type' request parameter of getContentList API
    # @param [String] sort                  Same as 'sort' request parameter of getContentList API
    # @param [Fixnum] date_count            Number of dates to get.
    # @param [Fixnum] content_count         Number of contents to get
    # @return [Array< Array<String, Fixnum> >]  Array of pairs of a date in format of 'YYYYMMDD' and a number of contents of the date.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_transfer
    #
    #   # Get all dates and the number of contents of the date
    #   dates = cam.get_date_list
    #   # Get 5 newest dates that contains at least one XAVC-S movie content.
    #   dates = cam.get_date_list(type: 'movie_xavcs', date_count: 5)
    #   # Get all dates that contains at least 10 still contents.
    #   dates = cam.get_date_list(type: 'still', content_count: 10)
    #
    #   dates.each do |date, count|
    #     # Get date and its content count
    #     puts "#{date['title']}, #{count}"
    #     # Get contents of each date
    #     contents = cam.get_content_list date: date['title']
    #     # Transfer contents
    #     cam.transfer_contents contents
    #   end
    def get_date_list(type: nil, sort: 'descending', date_count: nil, content_count: nil)
      type = Array(type) if type.is_a? String

      scheme = getSchemeList.result[0][0]['scheme']
      source = getSourceList([{'scheme' => scheme}]).result[0][0]['source']

      if type.present?
        # If type is specifid, get all dates and check the count of contents type later
        dates = get_content_list_sub(source, view: 'date', sort: sort)
      else
        # If not, simply get dates by date_count
        dates = get_content_list_sub(source, view: 'date', count: date_count, sort: sort)
      end

      # Filter by type, date_count and content_count.
      filtered_dates = []
      dates.each do |d|
        cnt = getContentCount([{'uri' => d['uri'], 'type' => type, 'view' => 'date'}]).result[0]['count']
        # Exclude days of 0 contents.
        filtered_dates << [d, cnt] if cnt > 0
        # Break if contents count exceeds.
        break if content_count and filtered_dates.map { |d, c| c }.inject(0, :+) > content_count
        # Break if date count exceeds.
        break if date_count and filtered_dates.size > date_count
      end
      filtered_dates
    end


    # Predefined transfer sizes
    SIZE_LIST = %w(original large small thumbnail).freeze
    # Transfer content(s) from the camera storage.
    # @note You have to set camera function to 'Contents Transfer' before calling this method.
    # @param [Array<Hash>] contents     Array of content information, which can be obtained by get_content_list
    # @param [Array<String>] filenames  Array of filename strings
    # @param [String] size              Content size. available values are 'original', 'large', 'small', 'thumbnail'.
    # @see get_content_list
    # @see get_date_list
    # @todo If 'contents' is directory (date), get all contents of the directory.
    def transfer_contents(contents, filenames=[], dir: nil, size: 'original')
      if SIZE_LIST.exclude?(size)
        log.error "#{size} is invalid for size option!"
        return nil
      end

      contents = [contents].compact unless contents.is_a? Array
      filenames = [filenames].compact unless filenames.is_a? Array
      if !filenames.empty?
        if contents.size > filenames.size
          log.warn 'Size of filename list is smaller than that of contents list!'
          filenames += Array.new(contents.size - filenames.size, nil)
        elsif contents.size < filenames.size
          log.warn 'Size of filename list is bigger than that of contents list!'
        end
      end

      urls_filenames = contents.zip(filenames).map do |content, filename|
        next unless content
        url =
            case size
              when 'original'
                raise StandardError if content['content']['original'].size > 1 # FIXME: When do we come here???
                content['content']['original'][0]['url']
              when 'large'
                content['content']['largeUrl']
              when 'small'
                content['content']['smallUrl']
              when 'thumbnail'
                content['content']['thumbnailUrl']
            end
        filename ||= content['content']['original'][0]['fileName']
        [url, filename]
      end

      log.info "#{contents.size} contents to be transferred."
      transferred = transfer_contents_sub(urls_filenames, dir)
      if transferred.size == urls_filenames.size
        log.info 'All transfer completed.'
      else
        log.info "Some files are failed to transfer (#{transferred.size}/#{urls_filenames.size})."
      end
      transferred
    end


    # Delete content(s) of camera storage.
    # @note You have to set camera function to 'Contents Transfer' before calling this method.
    # @param [Array<Hash>] contents array of content hashes, which can be obtained by get_content_list
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_transfer
    #
    #   # Delete 10 newest still contents
    #   contents = cam.get_content_list(type: still, count: 10)
    #   delete_contents(contents)
    def delete_contents(contents)
      contents = [contents].compact unless contents.is_a? Array
      count = contents.size
      (0..((count - 1) / 100)).each do |i|
        start = i * 100
        cnt = start + 100 < count ? 100 : count - start
        param = contents[start, cnt].map { |c| c['uri'] }
        deleteContent [{'uri' => param}]
      end
      log.info "Deleted #{contents.size} contents."
    end


    #----------------------------------------PRIVATE METHODS----------------------------------------

    private

    # Transfer a postview
    def transfer_postview(url, filename, dir: nil)
      filepath = dir ? File.join(dir, filename) : filename
      log.info "Transferring #{filepath}..."
      FileUtils.mkdir_p dir if dir
      result = true
      time = Benchmark.realtime do
        result = reconnect_and_give_up do
          open(filepath, 'wb') do |file|
            @cli.get_content(url) do |chunk|
              file.write chunk
            end
          end
          true
        end
      end
      if result
        log.info "Transferred #{filepath}. (#{format('%.2f', time)} sec)"
        filepath
      else
        log.info "Failed to transfer #{filepath}. (#{format('%.2f', time)} sec)"
        nil
      end
    end

    # Use postview size parameter to determine the image size to get
    def get_transfer_size
      return 'original' unless support? :getPostviewImageSize
      postview_size = getPostviewImageSize.result[0]
      case postview_size
        when 'Original'
          'original'
        when '2M'
          'large'
      end
    end


    # In burst shooting mode, the last one in 10 images is the only one we can get by postview URI.
    # So we must change function to 'Transfer Contents', then get the newest 10 contents.
    # The problem is that getContentList API can sort the results by timestamp but not by file number.
    # For example, assume that you have 2 cameras A and B, and the time setting of the A is ahead of B.
    # If you capture stills by A and then act burst shooting by B with the same SD card,
    # you will get stills captured by A, because the 'newest' contents are determined by timestamp.
    def transfer_in_burst_mode(url, prefix: nil, dir: nil)
      transfer_size = get_transfer_size
      change_function_to_transfer
      # As of now, burst shooting mode always capture 10 still images.
      contents = get_content_list type: 'still', sort: 'descending', count: 10
      if prefix.present?
        filenames = generate_sequencial_filenames prefix, 'JPG', num: 10
      else
        filenames = contents.map { |c| c['content']['original'][0]['fileName'] }
      end
      transferred = transfer_contents contents, filenames, size: transfer_size, dir: dir
      change_function_to_shoot 'still', 'Burst'
      transferred
    end


    def transfer_recorded_movie(filename: nil, dir: nil)
      change_function_to_transfer
      content = get_content_list type: ['movie_mp4', 'movie_xavcs'], sort: 'descending', count: 1
      transferred = transfer_contents content, filename, dir: dir
      change_function_to_shoot 'movie'
      transferred[0] if !transferred.empty?
    end


    def transfer_interval_stills(num_shots, prefix: nil, dir: nil)
      transfer_size = get_transfer_size
      change_function_to_transfer
      contents = get_content_list type: 'still', sort: 'descending', count: num_shots
      if prefix
        filenames = generate_sequencial_filenames prefix, 'JPG', num: contents.size
        transferred = transfer_contents contents, filenames, dir: dir
      else
        transferred = transfer_contents contents, size: transfer_size, dir: dir
      end
      change_function_to_shoot 'intervalstill'
      transferred
    end


    # Zoom until wide-end or tele-end.
    def zoom_until_end(absolute)
      case
        when absolute == 100
          actZoom ['in', 'start']
          wait_event(polling: true) { |r| r[2]['zoomPosition'] == absolute }
          actZoom ['in', 'stop']
        when absolute == 0
          actZoom ['out', 'start']
          wait_event(polling: true) { |r| r[2]['zoomPosition'] == absolute }
          actZoom ['out', 'stop']
      end
      absolute
    end


    LONG_ZOOM_THRESHOLD = 19
    LONG_ZOOM_FINISH_TIMEOUT = 0.5
    # Long push zoom is tend to go through the desired potision, so
    # LONG_ZOOM_THRESHOLD is a important parameter.
    def zoom_by_long_push(current, relative)
      # Return if relative is lesser than threshold
      return [current, relative] if relative.abs < LONG_ZOOM_THRESHOLD

      absolute = current + relative
      log.debug "  Long zoom start: #{current} -> #{absolute}"
      case
        when relative > 0
          target = absolute - LONG_ZOOM_THRESHOLD
          dir = 'in'
          condition = ->(r) { r[2]['zoomPosition'] > target }
        when relative < 0
          target = absolute + LONG_ZOOM_THRESHOLD
          dir = 'out'
          condition = ->(r) { r[2]['zoomPosition'] < target }
        else
          return [current, relative]
      end
      log.debug "    stopping line: #{target}"

      actZoom [dir, 'start']
      wait_event(polling: true, &condition)
      actZoom [dir, 'stop']

      # Wait for the lense stops completely
      final = current
      loop do
        begin
          final = wait_event(timeout: LONG_ZOOM_FINISH_TIMEOUT) { |r| r[2]['zoomPosition'] != final }[2]['zoomPosition']
        rescue EventTimeoutError => e
          break
        end
      end

      log.debug "  Long zoom finished: #{current} -> #{final} (target: #{absolute})"
      [final, absolute - final]
    end


    SHORT_ZOOM_THRESHOLD = 10
    SHORT_ZOOM_FINISH_TIMEOUT = 0.5
    # 1shot zoom
    def zoom_by_1shot(current, relative)
      # Return if relative is lesser than threshold
      return [current, relative] if relative.abs < SHORT_ZOOM_THRESHOLD

      absolute = current + relative
      log.debug "  Short zoom start: #{current} -> #{absolute}"

      diff = relative
      while true
        if diff > 0
          log.debug '    in'
          actZoom ['in', '1shot']
        elsif diff < 0
          log.debug '    out'
          actZoom ['out', '1shot']
        else
          break
        end
        pos = wait_event(polling: true) { |r| r[2]['zoomPosition'] }[2]['zoomPosition']
        diff = absolute - pos
        break if diff.abs < SHORT_ZOOM_THRESHOLD
      end

      # Wait for the lense stops completely
      final = current
      loop do
        begin
          final = wait_event(timeout: SHORT_ZOOM_FINISH_TIMEOUT) { |r| r[2]['zoomPosition'] != final }[2]['zoomPosition']
        rescue EventTimeoutError => e
          break
        end
      end

      log.debug "  Short zoom finished: #{current} -> #{final} (target: #{absolute})"
      [final, absolute - final]
    end


    # Initialize and start liveview
    def init_liveview(size: nil)
      # Enable liveview frame information if available
      rsp = setLiveviewFrameInfo!([{'frameInfo' => true}])
      if rsp && rsp.result
        frame_info_enabled = true
      else
        frame_info_enabled = false
      end

      if size
        # need to stop liveview when the liveview size is changed
        stopLiveview
        current, available = getAvailableLiveviewSize.result
        unless available.include?(size)
          raise IllegalArgument, new, "The value '#{size}' is not available for parameter 'LiveviewSize'. current: #{current}, available: #{available}"
        end
        [ startLiveviewWithSize([size]).result[0], frame_info_enabled ]
      else
        [ startLiveview.result[0], frame_info_enabled ]
      end
    end


    def get_content_list_sub(source, type: nil, target: 'all', view:, sort:, count: nil)
      max_count = getContentCount([{'uri' => source, 'type' => type, 'view' => view}]).result[0]['count']
      count = count ? [max_count, count].min : max_count
      contents = []
      (0..((count - 1) / 100)).each do |i|
        start = i * 100
        cnt = start + 100 < count ? 100 : count - start
        contents += getContentList([{'uri' => source, 'stIdx' => start, 'cnt' => cnt, 'type' => type, 'view' => view, 'sort' => sort}]).result[0]
        # pp contents
      end
      contents
    end


    def transfer_contents_sub(urls_filenames, dir)
      FileUtils.mkdir_p dir if dir
      transferred = []
      urls_filenames.each do |url, filename|
        next unless url
        filepath = dir ? File.join(dir, filename) : filename
        log.debug url
        log.info "Transferring #{filepath}..."
        time = Benchmark.realtime do
          reconnect_and_retry(hook: method(:change_function_to_transfer)) do
            open(filepath, 'wb') do |file|
              @cli.get_content(url) do |chunk|
                file.write chunk
              end
            end
          end
        end
        log.info "Transferred #{filepath}. (#{format('%.2f', time)} sec)"
        transferred << filepath
      end
      transferred
    end


    # Try to run given block.
    # If an error raised because of the Wi-Fi disconnection, try to reconnect and run the block again.
    # If error still continues, give it up and raise the error.
    def reconnect_and_retry(retrying: true, num: 1, hook: nil)
      yield
    rescue HTTPClient::TimeoutError, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
      retry_count ||= 0
      raise e if @reconnect_by.nil? || retry_count >= num
      log.error "#{e.class}: #{e.message}"
      log.error 'The camera seems to be disconnected! Reconnecting...'
      unless @reconnect_by.call
        log.error 'Failed to reconnect.'
        raise e
      end
      log.error 'Reconnected.'
      @cli.reset_all
      # For cameras that use Smart Remote Control app.
      startRecMode! timeout: 0

      if hook
        unless hook.call
          log.error 'Before-retry hook failed.'
          raise e
        end
      end
      retry_count += 1
      retry if retrying
    end

    def reconnect_and_retry_forever(&block)
      reconnect_and_retry &block
    rescue HTTPClient::TimeoutError, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
      retry
    end

    def reconnect_and_give_up(&block)
      reconnect_and_retry(retrying: false, &block)
    end
  end
end
