require 'sony_camera_remote_api/logging'

module SonyCameraRemoteAPI
  class Retrying
    include Logging

    RECONNECTION_INTERVAL = 5
    DEFAULT_RETRY_LIMIT = 2
    DEFAULT_RECONNECTION_LIMIT = 2


    def initialize(reconnect_by, httpclient)
      @reconnect_by = reconnect_by
      @http = httpclient
    end


    def reconnect_and_retry(retry_limit: DEFAULT_RETRY_LIMIT,
                            reconnection_limit: DEFAULT_RECONNECTION_LIMIT,
                            hook: nil, &block)
      reconnect_and_retry_inner(retry_limit, reconnection_limit, hook, &block)
    end


    def reconnect_and_give_up(reconnection_limit: DEFAULT_RECONNECTION_LIMIT,
                              hook: nil, &block)
      reconnect_and_retry_inner(0, reconnection_limit, hook, &block)
    end


    def reconnect_and_retry_forever(hook: nil, &block)
      reconnect_and_retry_inner(:forever, :forever, hook, &block)
    end


    def add_common_hook(&block)
      @common_hook = block
      self
    end


    private

    # Execute given block with reconnection and retry.
    # When the given block raises Error caused by Wi-Fi disconnection,
    # Try to reconnect by @reconnect_by Proc, and then execute again the given block.
    # @param [Fixnum] retry_limit         Limit number of retrying given block.
    # @param [Fixnum] reconnection_limit  Limit number of retrying reconnection.
    # @param [Proc]   one_off_hook        Hook method called after reconnection.
    def reconnect_and_retry_inner(retry_limit, reconnection_limit, one_off_hook)
      # Try to execute the given block by 'retry_limit' times.
      yield
    rescue HTTPClient::BadResponseError, HTTPClient::TimeoutError, Errno::EHOSTUNREACH, Errno::ECONNREFUSED => e
      # Reraise immediately if reconnection is disabled
      raise e if @reconnect_by.nil?

      log.error "#{e.class}: #{e.message}"
      # Init retry_count
      retry_count ||= 0
      if retry_count == 0
        log.error 'The camera seems to be disconnected, starting retry sequence.'
        forever = retry_limit.is_a?(Symbol) &&  retry_limit == :forever
      else
        if  forever || retry_count < retry_limit
          log.error "Failed to execute the block! (#{retry_count}/#{retry_limit})"
        else
          log.error 'Execution failed! Finishing retry sequence...'
          raise e
        end
      end

      # Try to reconnect by 'reconnection_limit' times.
      unless try_to_reconnect reconnection_limit
        log.error 'Reconnection failed! Finishing retry sequence...'
        raise e
      end

      # Call hooks
      @common_hook.call if @common_hook
      one_off_hook.call if one_off_hook

      # Increment retry count
      retry_count += 1
      retry
    end


    def try_to_reconnect(limit)
      log.error 'Reconnecting...'
      forever = limit.is_a?(Symbol) &&  limit == :forever
      reconnection_count = 0
      loop do
        reconnection_count += 1
        return false unless forever || reconnection_count <= limit
        break if @reconnect_by.call
        log.error "Failed to reconnect! Retrying... (#{reconnection_count}/#{limit})"
        sleep RECONNECTION_INTERVAL
      end
      @http.reset_all
      log.error 'Reconnected.'
      true
    end

  end
end
