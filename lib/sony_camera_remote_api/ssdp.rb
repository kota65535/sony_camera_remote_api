require 'frisky/ssdp'
require 'httpclient'
require 'nokogiri'
require 'json'

module SonyCameraRemoteAPI
  # Module providing SSDP function to discover camera (Device discovery)
  module SSDP

    # Cannot find camera
    class DeviceNotFound < StandardError;
    end
    # Failed to Parse device description
    class DeviceDescriptionInvalid < StandardError;
    end

    # The search target for Sony camera (fixed)
    SSDP_SEARCH_TARGET = 'urn:schemas-sony-com:service:ScalarWebAPI:1'.freeze
    # Retrying limit for SSDP search
    SSDP_SEARCH_RETRY = 4
    # Retrying interval for SSDP search
    SSDP_RETRY_INTERVAL = 5

    # Perform SSDP discover to find camera on network.
    # @return [Hash] Endpoint URLs
    def ssdp_search
      log.info 'Trying SSDP discover...'
      try = 1
      while true do
        response = Frisky::SSDP.search SSDP_SEARCH_TARGET
        if response.present?
          break
        elsif try < SSDP_SEARCH_RETRY
          try += 1
          log.warn "SSDP discover failed, retrying... (#{try}/#{SSDP_SEARCH_RETRY})"
          sleep(SSDP_RETRY_INTERVAL)
        else
          raise DeviceNotFound, 'Cannot find camera API server. Please confirm network connection is correct.'
        end
      end
      log.info 'SSDP discover succeeded.'

      # get device description
      dd = HTTPClient.new.get_content(response[0][:location])
      # puts dd
      parse_device_description(dd)
    end


    # Parse device description and get endpoint URLs
    def parse_device_description(dd)
      dd_xml = Nokogiri::XML(dd)
      raise DeviceDescriptionInvalid if dd_xml.nil?
      dd_xml.remove_namespaces!
      camera_name = dd_xml.css('device friendlyName').inner_text
      services = dd_xml.css('device X_ScalarWebAPI_Service')
      endpoints = {}
      services.each do |sv|
        service_type = sv.css('X_ScalarWebAPI_ServiceType').inner_text
        endpoints[service_type] = File.join(sv.css('X_ScalarWebAPI_ActionList_URL').inner_text, service_type)
      end
      # endpoints['liveview'] = dd_xml.css('device X_ScalarWebAPI_LiveView_URL').inner_text
      # endpoints.delete_if { |k, v| v.blank? }
      log.info "model-name: #{camera_name}"
      log.debug 'endpoints:'
      endpoints.each do |e|
        log.debug "  #{e}"
      end
      endpoints
    end
  end
end
