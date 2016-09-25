require 'sony_camera_remote_api/camera_api'

module SonyCameraRemoteAPI
  # Camera API group sublayer class, which is included in Camera API layer class.
  # This class handles API groups that get/set specific parameters of the camera.
  class CameraAPIGroupManager
    include Logging
    include Utils

    # APIGroup class.
    # One API group object represents one camera parameter.
    class APIGroup

      # Create API group object.
      # @param [Symbol] param_symbol      API Group name
      # @param [Proc] supported_accessor  Get the supported values from getSupportedXXX raw response.
      # @param [Proc] available_accessor  Get the available values from getAvailableXXX raw response.
      # @param [Proc] get_accessor        Get the current value from getXXX raw response.
      # @param [Proc] set_accessor        Set given value to setXXX request.
      # @param [Proc] start_condition     Wait until given condition before accessing parameter.
      # @param [Proc] preprocess_value    Convert given value and arguments into the internal format to be compared.
      # @param [Proc] check_equality      Compare given value and current one to judge whether new value should be set or not.
      # @param [Proc] check_availability  Compare given value and avialable ones to judge whether new value is available.
      # @param [Proc] end_condition       Wait until given condition after changing parameter.
      def initialize(param_symbol, supported_accessor, available_accessor, get_accessor, set_accessor,
                     start_condition: nil,
                     preprocess_value: nil,
                     check_equality: method(:default_check_equality),
                     check_availability: method(:default_check_availability),
                     end_condition: nil
                     )
        @param_str = param_symbol.to_s
        @supported = ('getSupported' + @param_str).to_sym
        @supported_accessor = supported_accessor
        @available = ('getAvailable' + @param_str).to_sym
        @available_accessor = available_accessor
        @get = ('get' + @param_str).to_sym
        @get_accessor = get_accessor
        @set = ('set' + @param_str).to_sym
        @set_accessor = set_accessor
        @start_condition = start_condition
        @preprocess_value = preprocess_value
        @check_equality = check_equality
        @check_availability = check_availability
        @end_condition = end_condition
      end

      # Get suported values of this parameter through the defined accessor
      # @param [CameraAPIManager] api_manager
      # @param [Array<Hash>] condition
      def supported_values(api_manager, condition, **opts)
        raw_result = api_manager.send(@supported, **opts)['result']
        { supported: @supported_accessor.call(raw_result, condition) }
      end

      # Get available values of this parameter through the defined accessor
      # @param [CameraAPIManager] api_manager
      # @param [Array<Hash>] condition
      def available_values(api_manager, condition, **opts)
        raw_result = api_manager.send(@available, **opts)['result']
        { available: @available_accessor.call(raw_result, condition) }
      end

      # Get current values of this parameter through the defined accessor
      def current_value(api_manager, condition, **opts)
        raw_result = api_manager.send(@get, **opts)['result']
        { current: @get_accessor.call(raw_result, condition) }
      end

      # If start_condition is defined, wait until the condition satisfies.
      # @param [CameraAPIManager] api_manager
      def start_condition(api_manager, **opts)
        if @start_condition
          api_manager.wait_event { |r| @start_condition.call(r) }
        end
      end

      # Preprocess given value and arguments to the value which can be compared.
      # @param [Object] value
      # @param [Array] args
      # @param [Array<Hash>] condition
      def preprocess_value(value, args, condition)
        if @preprocess_value
          @preprocess_value.call(value, args, condition)
        else
          value
        end
      end

      def is_available?(value, available_values, condition)
        @check_availability.call(value, available_values, condition)
      end


      def eq_current?(value, current_value, condition)
        @check_equality.call(value, current_value, condition)
      end

      # @param [CameraAPIManager] api_manager
      # @param [Object] value
      # @param [Array] availables
      # @param [Array<Hash>] condition
      def set_value(api_manager, value, availables, condition)
        api_manager.send(@set, @set_accessor.call(value, availables, condition))
        if @end_condition
          condition_block = (@end_condition.curry)[value]
          api_manager.wait_event &condition_block
        end
        { current: value }
      end

      private

      def default_check_availability(value, available_values, condition)
        available_values.include? value
      end

      def default_check_equality(value, current_value, condition)
        current_value == value
      end

    end


    # Create CameraAPIManager object.
    # @param [CameraAPIManager] camera_api_manager
    def initialize(camera_api_manager)
      @api_manager = camera_api_manager
      @api_groups = make_api_group_list camera_api_manager.apis
    end


    # Get current value of the camera parameter.
    # @param [Symbol] group_name Parameter name
    # @return [Object] Current value
    # @raise APIForbidden, APINotSupported, APINotAvailable, IllegalArgument
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   value = cam.get_current :ContShootingMode
    #   puts value      #=> 'Burst', 'MotionShot', Continuous' ...
    def get_current(group_name, **opts)
      get_parameter(group_name, available: false, supported: false, **opts)[:current]
    end


    # Almost same as get_current, but this method does not raise Exception.
    # @return [Object, nil] Current value or nil if any error occurred.
    # @see get_current
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   value = cam.get_current! :ContShootingMode
    #   if value
    #     puts "ContShootingMode is supported, and current value is #{value}"
    #   else
    #     puts 'ContShootingMode is not supported.'
    #   end
    def get_current!(group_name, **opts)
      get_parameter!(group_name, available: false, supported: false, **opts)[:current]
    end


    # Get supported/available/current value of the camera parameter.
    # @param [Symbol] group_name Parameter name
    # @param [Boolean] available Flag to get available values
    # @param [Boolean] supported Flag to get supported values
    # @return [Hash]  current/available/supported values
    # @raise APIForbidden, APINotSupported, APINotAvailable, IllegalArgument
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'movie'
    #
    #   result = cam.get_parameter :ExposureMode
    #   puts "current value   : #{result[:current]}"
    #   puts "available values: #{result[:available]}"
    #   puts "supported values: #{result[:supported]}"
    def get_parameter(group_name, available: true, supported: true, **opts)
      result = { current: nil, available: [], supported: [] }
      begin
        grp = search_group group_name
      rescue APIForbidden, APINotSupported => e
        raise e.class.new(result), e.message
      end
      condition = grp.start_condition(@api_manager)
      begin
        result.merge! grp.current_value(@api_manager, condition, **opts)
      rescue APINotAvailable, IllegalArgument => e
        raise e.class.new(result), e.message
      end
      begin
        # Timeout is set shorter than usual for getting hardware-affected parameter.
        result.merge! grp.available_values(@api_manager, condition, timeout: 1, **opts) if available
        result.merge! grp.supported_values(@api_manager, condition, timeout: 1, **opts) if supported
      rescue APINotAvailable, IllegalArgument => e
        # Comes here if the parameter is hardware-affected.
      end
      result
    end


    # Almost same as get_parameter, but this method does not raise Exception.
    # @return [Hash] current/available/supported values. If any error occurs, the value that cannot get become nil or empty array.
    # @see get_parameter
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   result = cam.get_parameter! :ExposureMode
    #   if result[:current]
    #     puts 'ExposureMode is supported.'
    #     if result[:available] && result[:supported]
    #       puts 'And you can change the value by #set_parameter.'
    #     else
    #       puts 'And you can change the value by the hardware dial or switch (NOT by #set_parameter).'
    #     end
    #   else
    #     puts 'ExposureMode is not supported!'
    #   end
    def get_parameter!(group_name, **opts)
      get_parameter(group_name, **opts)
    rescue APIForbidden, APINotSupported, APINotAvailable, IllegalArgument => e
      log.error e.message
      e.object
    rescue HTTPClient::BadResponseError => e
      log.error e.message
    end


    # Set the camera parameter to the given value.
    # @param [Symbol] group_name Parameter name
    # @param [Object] value New value to be set
    # @return [Hash]  current/available/old values after setting parameter.
    # @raise APIForbidden, APINotSupported, APINotAvailable, IllegalArgument
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   result = cam.set_parameter :FlashMode, 'on'
    #   puts "current value   : #{result[:current]}"
    #   puts "available values: #{result[:available]}"
    #   puts "old value       : #{result[:old]}"
    def set_parameter(group_name, value, *args, **opts)
      result = { current: nil, available: [], old: nil }
      begin
        grp = search_group group_name
      rescue APIForbidden, APINotSupported => e
        raise e.class.new(result), e.message
      end

      condition = grp.start_condition(@api_manager)
      begin
        value = grp.preprocess_value(value, args, condition)
        # If value is equal to current value, do nothing.
        result.merge! grp.current_value(@api_manager, condition, **opts)
        result[:old] = result[:current]
        if grp.eq_current? value, result[:current], condition
          return result
        end
        # If not, check if the value is available.
        result.merge! grp.available_values(@api_manager, condition, **opts)
        if grp.is_available? value, result[:available], condition
          # Save current value and call set API.
          result[:old] = result[:current]
          result.merge! grp.set_value(@api_manager, value, result[:available], condition)
        else
          # If the value is not available, raise error.
          raise IllegalArgument.new, "The value '#{value}' is not available for parameter '#{group_name}'. current: #{result[:current]}, available: #{result[:available]}"
        end
      rescue APINotAvailable, IllegalArgument => e
        raise e.class.new(result), e.message
      end
      result
    end


    # Almost same as set_parameter, but this method does not raise Exception.
    # @return [Hash] current/available/old values after setting parameter.
    #   If any error occurs, the value that cannot get become nil or empty array.
    # @see set_parameter
    # @example
    #   # Initialize
    #   cam = SonyCameraRemoteAPI::Camera.new
    #   cam.change_function_to_shoot 'still', 'Single'
    #
    #   result = cam.set_parameter! :FlashMode, 'on'
    #   if result[:current]
    #     puts 'FlashMode is supported.'
    #     if result[:current] == 'on'
    #       puts "And successfully set the value to '#{result[:current]}'."
    #     else
    #       puts 'But cannot set the value.'
    #     end
    #   else
    #     puts 'FlashMode is not supported!'
    #   end
    def set_parameter!(group_name, value, **opts)
      set_parameter(group_name, value, **opts)
    rescue APIForbidden, APINotSupported, APINotAvailable, IllegalArgument => e
      log.error e.message
      e.object
    rescue HTTPClient::BadResponseError => e
      log.error e.message
    end


    # Get an array of supported camera parameters.
    # @return [Array<String>] supported camera parameters
    def parameters
      @api_groups.keys
    end


    # Returns whether the parameter is supported or not.
    # @return [Boolean] +true+ if the parameter is supported, false otherwise.
    def support_group?(group_name)
      @api_groups.key? group_name
    end


    private

    # Make API Group hash list from APIInfo list.
    # @param [Array<APIInfo>] apis
    # @return [Hash<Symbol, APIGroup>]
    def make_api_group_list(apis)
      api_names = apis.values.map { |a| a.name }
      setters = api_names.select { |k| k =~ /^getAvailable/ }
      api_groups = {}
      setters.map do |s|
        group_name = s.gsub(/^getAvailable/, '')
        members = [ "get#{group_name}", "getAvailable#{group_name}", "getSupported#{group_name}" ]
        result = members.map { |m| api_names.include?(m) }
        api_groups[group_name.to_sym] = @@api_groups_all[group_name.to_sym] if result.all?
      end
      api_groups
    end

    # @param [Symbol] group_name
    def search_group(group_name)
      if support_group? group_name
        return @api_groups[group_name]
      else
        raise APINotSupported.new, "Parameter '#{group_name}' is not supported!"
      end
    end

    require 'sony_camera_remote_api/camera_api_group_def'

  end
end
