require 'sony_camera_remote_api/raw_api'
require 'sony_camera_remote_api/camera_api_group'
require 'forwardable'

module SonyCameraRemoteAPI

  # Camera API layer class, which enables us to handle camera APIs more friendly.
  class CameraAPIManager
    extend Forwardable
    include Logging

    # Default timeout for waiting camera API becomes available
    DEFAULT_API_CALL_TIMEOUT = 8
    # Default timeout for waiting camera parameter changes
    DEFAULT_PARAM_CHANGE_TIMEOUT = 15

    def_delegators :@api_group_manager, :get_parameter, :get_parameter!,
                                        :set_parameter, :set_parameter!,
                                        :get_current, :get_current!
    def_delegators :@raw_api_manager, :apis



    # Create CameraAPIManager object.
    # @param [Hash] endpoints
    # @param [Proc] reconnect_by
    def initialize(endpoints, reconnect_by: nil)
      @raw_api_manager = RawAPIManager.new endpoints
      @api_group_manager = CameraAPIGroupManager.new self
      @reconnect_by = reconnect_by
    end


    # getEvent API.
    # Long polling flag is set true as default.
    # @param [Array,String] params
    # @return [Hash]  Response of API
    def getEvent(params = [true], **opts)
      params = [params] unless params.is_a? Array
      name, service, id, version = @raw_api_manager.search_method(__method__, **opts)
      response = nil
      reconnect_and_retry do
        if params[0]
          response = @raw_api_manager.call_api_async(service, name, params, id, version, opts[:timeout])
        else
          response = @raw_api_manager.call_api(service, name, params, id, version)
        end
      end
      response
    end


    # getAvailableApiList API.
    # @return [Hash]  Response of API
    def getAvailableApiList(params = [], **opts)
      name, service, id, version = @raw_api_manager.search_method(__method__, **opts)
      reconnect_and_retry do
        @raw_api_manager.call_api(service, name, params, id, version)
      end
    end


    # Wait until 'getEvent' result response meets the specified condition.
    # This method can be used to wait after calling APIs that change any camera parameters, such as 'setCameraFunction'.
    # @yield [Array<Hash>] The block that returns +true+ or +false+ based on the condition of the response of getEvent
    # @yieldparam [Array<Hash>] 'result' element in the response of getEvent
    # @param [Fixnum] timeout   Timeout in seconds for changing parameter
    # @param [Boolean] polling  This method has 3 patterns to handle long polling flag by 'polling' parameter.
    #   * default : The first getEvent call doesn't use long polling, but then later always use long polling.
    #   * polling = true  : Always use long polling in getEvent call
    #   * polling = false : Never use long polling in getEvent call
    # @raise EventTimeoutError
    def wait_event(timeout: DEFAULT_PARAM_CHANGE_TIMEOUT, polling: nil, &block)
      start_time = Time.now if timeout
      # Long-polling is disabled only at the first call
      poll = polling.nil? ? false : polling
      while true do
        response = get_event_both(poll, timeout: timeout)
        begin
          break if yield(response.result)
        rescue StandardError => e
          # Catch all exceptions raised by given block, e.g. NoMethodError of '[]' for nil class.
        end
        sleep 0.1
        if timeout
          raise EventTimeoutError, "Timeout expired: #{timeout} sec." if Time.now - start_time > timeout
        end
        poll = polling.nil? ? true : polling
        log.debug "Waiting for #{block} returns true..."
      end
      log.debug "OK. (#{format('%.2f', Time.now-start_time)} sec.)"
      # pp response['result']
      response['result']
    end


    # Ghost method, which handles almost API calls.
    # You can call an API as a method with the same name.
    # We don't have to specify service_type and version for almost APIs.
    # But some APIs have multiple service types and versions, so that we have to specify one service type or version.
    # When '!' is appended to the end of the method name, it does not raise Exception even if any error occurred.
    # @param [String] method
    # @param [Array,String] params
    # @param [String] service_type
    # @param [Fixnum] id
    # @param [String] version
    # @param [Fixnum] timeout   Timeout in seconds for waiting until the API is available
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   # Call getMethodTypes API with parameter: ['1.0'], service type: 'camera' and id: 1.
    #   response = cam.getMethodTypes ['1.0'], service_type: 'camera', id: 1
    #   puts response.id
    #   response.results.each do |r|
    #     puts '----'
    #     puts r
    #   end
    #
    #   # Call setCurrentTime API if supported.
    #   cam.setCurrentTime! [{'dateTime' => Time.now.utc.iso8601,
    #                       'timeZoneOffsetMinute' => 540,
    #                       'dstOffsetMinute' => 0}]
    def method_missing(method, params = [], *args, **opts)
      ignore_error = true if method.to_s.end_with? '!'
      method = method.to_s.delete('!').to_sym
      params = [params] unless params.is_a? Array
      response = nil
      reconnect_and_retry do
        begin
          name, service, id, version = @raw_api_manager.search_method(method, **opts)
          if service == 'camera' || name == ''
            if opts[:timeout]
              response = call_api_safe(service, name, params, id, version, opts[:timeout], **opts)
            else
              response = call_api_safe(service, name, params, id, version, **opts)
            end
          else
            response = @raw_api_manager.call_api(service, name, params, id, version)
          end
        rescue APIForbidden, APINotSupported, APINotAvailable, IllegalArgument, HTTPClient::BadResponseError => e
          if ignore_error
            return nil
          else
            raise e
          end
        end
      end
      response
    end


    # Get whether the API or API group is supported by a camera.
    # @param [Symbol] api_or_group_name The API or API group name
    # @return [Boolean] +true+ if supported, +false+ otherwise.
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   # Check if actZoom API is supported.
    #   puts cam.support? :actZoom
    #   # Check if ZoomSetting API group is supported.
    #   puts cam.support? :ZoomSetting
    def support?(api_or_group_name)
      @raw_api_manager.support?(api_or_group_name) || @api_group_manager.support_group?(api_or_group_name)
    end


    private

    # Call camera APIs with checking if it is available by 'getAvailableApiList'.
    # If not available, wait a minute until the called API turns to be available.
    # @param [String] service_type
    # @param [String] method
    # @param [Array,String] params
    # @param [Fixnum] id
    # @param [String] version
    # @param [Fixnum] timeout Timeout in seconds for waiting until the API is available
    def call_api_safe(service_type, method, params, id, version, timeout = DEFAULT_API_CALL_TIMEOUT, **args)
      unless getAvailableApiList['result'][0].include? method
        log.error "Method '#{method}' is not available now! waiting..."
        begin
          wait_event(timeout: timeout) { |res| res[0]['names'].include? method }
        rescue EventTimeoutError => e
          raise APINotAvailable.new, "Method '#{method}' is not available now!"
        end
        log.info "Method '#{method}' has become available."
      end
      @raw_api_manager.call_api(service_type, method, params, id, version)
    end


    # Call getEvent without polling if getEvent with polling failed.
    def get_event_both(poll, timeout: nil)
      getEvent(poll, timeout: timeout)
    rescue EventTimeoutError => e
      getEvent(false)
    end


    # Execute given block. And if the block raises Error caused by Wi-Fi disconnection,
    # Reconnect by @reconnect_by Proc and retry the given block.
    # @param [Boolean] retrying If true, retry given block. If false, return immediately after reconnection.
    # @param [Fixnum] num       Number of retry.
    # @param [Proc] hook        Hook method called after reconnection.
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
      @raw_api_manager.reset_connection
      # For cameras that use Smart Remote Control app.
      startRecMode! timeout: 0
      return unless retrying

      if hook
        unless hook.call
          log.error 'Before-retry hook failed.'
          raise e
        end
      end
      retry_count += 1
      retry
    end
  end
end
