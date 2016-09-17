module SonyCameraRemoteAPI
    # Camera is not compatible to Camera Remote API.
    class ServerNotCompatible < StandardError; end
    # Given version for the API is invalid
    class APIVersionInvalid < StandardError; end
    # Given service type for the API is invalid
    class ServiceTypeInvalid < StandardError; end
    # API is proviced by multiple services, but user did not specified it
    class ServiceTypeNotGiven < StandardError; end

    # Waiting for event notification of camera parameter change timed out
    class EventTimeoutError < StandardError; end

    # Base Error class having some information as object.
    class StandardErrorWithObj < StandardError
      attr_reader :object
      def initialize(object = nil)
        @object = object
      end
    end

    # This API is not supported by the camera
    class APINotSupported < StandardErrorWithObj; end
    # This API is supported but not available now
    class APINotAvailable < StandardErrorWithObj; end
    # Given argument is not available
    class IllegalArgument < StandardErrorWithObj; end
    # This API is forbidden to the general users
    class APIForbidden < StandardErrorWithObj; end

    # API returned error response
    class APIExecutionError < StandardError
      attr_reader :method, :request, :err_code, :err_msg
      def initialize(method, request, response)
        @method = method
        @request = request
        @err_code = response['error'][0]
        @err_msg = response['error'][1]
      end
    end
end
