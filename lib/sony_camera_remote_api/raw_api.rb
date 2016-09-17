require 'sony_camera_remote_api/error'
require 'httpclient'

module SonyCameraRemoteAPI

  # Raw API layer class, which call APIs by HTTP POST to endpoint URLs and recieve the response.
  class RawAPIManager
    include Logging

    # API Information class
    class APIInfo
      attr_accessor :name, :versions, :service_types

      def initialize(name, versions, service_types)
        @name = name
        @versions = [versions]
        @service_types = [service_types]
      end

      def multi_versions?
        @versions.length > 1
      end

      def multi_service_types?
        @service_types.length > 1
      end
    end

    attr_reader :apis


    # @param [Hash] endpoints Endpoint URIs
    def initialize(endpoints)
      @endpoints = endpoints
      @cli = HTTPClient.new
      @cli.connect_timeout  = @cli.send_timeout = @cli.receive_timeout = 30

      unless call_api('camera', 'getApplicationInfo', [], 1, '1.0').result[1] >= '2.0.0'
        raise ServerNotCompatible, 'API version of the server < 2.0.0.'
      end
      @apis = make_api_list
    end


    # Make supported API list
    # @return [Hash<Symbol, APIInfo>] API list
    def make_api_list
      apis = {}
      @endpoints.keys.each do |s|
        versions = call_api(s, 'getVersions', [], 1, '1.0')['result'][0].sort.reverse
        versions.each do |v|
          results = call_api(s, 'getMethodTypes', [v], 1, '1.0')['results']
          next unless results
          results.each do |r|
            name = r[0].to_sym
            if apis.key?(name)
              apis[name].versions << v unless apis[name].versions.index(v)
              apis[name].service_types << s unless apis[name].service_types.index(s)
            else
              apis[name] = APIInfo.new(r[0], v, s)
            end
          end
        end
      end
      apis
    end


    # Call API by HTTP POST.
    # @param [String] service_type
    # @param [String] method
    # @param [Array, String] params
    # @param [Fixnum] id
    # @param [String] version
    # @return [Hash]  Response of API
    def call_api(service_type, method, params, id, version)
      params = [params] unless params.is_a? Array
      request = {
        'method' => method,
        'params' => params,
        'id' => id,
        'version' => version
      }
      # log.debug request
      begin
        raw_response = @cli.post_content(@endpoints[service_type], request.to_json)
      rescue HTTPClient::BadResponseError => e
        if e.res.status_code == 403
          raise APIForbidden.new, "Method '#{method}' returned 403 Forbidden error. Maybe this method is not allowed to general users."
        else
          raise e
        end
      end
      response = JSON.parse(raw_response)
      if response.key? 'error'
        raise APIExecutionError.new(method, request, response), "Request:#{request}, Response:#{response}"
      end
      # log.debug response
      response
    end


    # Asynchronous call API by HTTP POST.
    # Currently only used by 'getEvent' API with long polling.
    # @param [String] service_type
    # @param [String] method
    # @param [Array, String] params
    # @param [Fixnum] id
    # @param [String] version
    # @param [Fixnum] timeout Timeout in seconds for waiting response
    # @return [Hash]  Response of API
    def call_api_async(service_type, method, params, id, version, timeout = nil)
      request = {
        'method' => method,
        'params' => params,
        'id' => id,
        'version' => version
      }
      conn = @cli.post_async(@endpoints[service_type], request.to_json)
      start_time = Time.now if timeout
      loop do
        break if conn.finished?
        if timeout
          raise EventTimeoutError, "Timeout expired: #{timeout} sec." if Time.now - start_time > timeout
        end
        sleep 0.1
      end
      raw_response = conn.pop.content.read
      response = JSON.parse(raw_response)
      if response.key? 'error'
        raise APIExecutionError.new(method, request, response), "Request:#{request}, Response:#{response}"
      end
      response
    end


    # Search given API from API list.
    # @param [Symbol] method  The method name
    # @param [String] service
    # @param [Fixnum] id
    # @param [String] version
    def search_method(method, **opts)
      if @apis && @apis.key?(method)
        api_info = @apis[method]
        # use ID=1 if not given
        id = opts.key?(:id) ? opts[:id] : 1
        if opts.key? :version
          if api_info.versions.include? opts[:version]
            version = opts[:version]
          else
            raise APIVersionInvalid, "The version '#{opts[:version]}' is invalid for method '#{method}'."
          end
        else
          # use newest version if not given
          if api_info.multi_versions?
            # log.debug "Using newest version '#{api_info.versions[0]}' for method '#{method}'."
          end
          version = api_info.versions[0]
        end
        if opts.key? :service
          service = opts[:service]
          if api_info.service_types.include? opts[:service]
            service = opts[:service]
          else
            raise ServiceTypeInvalid, "The service type '#{opts[:service]}' is invalid for method '#{method}'."
          end
        else
          # raise error if service type is not given for method having multi service types
          if api_info.multi_service_types?
            strs = api_info.service_types.map { |item| "'#{item}'" }
            raise ServiceTypeNotGiven, "The method '#{method}' must be specified service type from #{strs.join(' or ')}."
          end
          service = api_info.service_types[0]
        end
        return api_info.name, service, id, version
      else
        raise APINotSupported.new, "The method '#{method}' is not supported by this camera."
      end
    end


    # @param [Symbol] method The method name
    # @return [Boolean] +true+ if the API is supported by this camera. +false+ otherwise.
    def support?(method)
      @apis.key? method
    end


    # Reset HTTPClient.
    # @return [void]
    def reset_connection
      @cli.reset_all
    end

  end
end
