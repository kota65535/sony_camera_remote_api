require 'bindata'

module SonyCameraRemoteAPI

  # The payload of Liveview image packet
  # @private
  class LiveviewImagePayload < BinData::Record
    endian :big
    # Payload header part
    uint32 :start_code, assert: 0x24356879
    uint24 :payload_data_size_wo_padding
    uint8  :padding_size
    uint32
    uint8 :flag
    uint920
    # Payload data part
    string :jpeg_data, :length => lambda { payload_data_size_wo_padding }
    string :padding_data, :length => lambda { padding_size }
  end

  # Liveview frame information data version
  # @private
  class DataVersion < BinData::Record
    endian :big
    uint8 :major
    uint8 :minor
  end

  # Point of liveview frame data
  class Point < BinData::Record
    endian :big
    uint16 :x
    uint16 :y
  end

  # The payload of Liveview frame information packet
  # @private
  class LiveviewFrameInformationPayload < BinData::Record
    endian :big
    # Payload header part
    uint32 :start_code, assert: 0x24356879
    uint24 :payload_data_size_wo_padding
    uint8  :padding_size
    data_version :frame_information_data_version
    uint16 :frame_count
    uint16 :single_frame_data_size
    uint912
    # Payload data part
    array :frame_data, :initial_length => lambda { frame_count } do
      point  :top_left
      point  :bottom_right
      uint8  :category
      uint8  :status
      uint8  :additional_status
      uint40
      string :padding_data, :length => lambda { padding_size }
    end
  end

  # Liveview packet definition
  # @private
  class LiveviewPacket < BinData::Record
    endian :big
    uint8  :start_byte, assert: 0xFF
    uint8  :payload_type, assert: -> { value == 0x01 || value == 0x02 }
    uint16 :sequence_number
    uint32 :time_stamp
    choice :payload, selection: :payload_type do
      liveview_image_payload 0x01
      liveview_frame_information_payload 0x02
    end
  end


  # Liveview image class
  class LiveviewImage
    attr_reader :sequence_number, :time_stamp, :jpeg_data
    def initialize(packet)
      @sequence_number = packet.sequence_number
      @time_stamp = packet.time_stamp
      @jpeg_data = packet.payload.jpeg_data
    end
  end

  # Liveview frame information class
  class LiveviewFrameInformation
    # Frame class
    class Frame
      attr_reader :top_left, :bottom_right, :category, :status, :additional_status

      def initialize(frame)
        @top_left = frame.top_left
        @bottom_right = frame.bottom_right
        @category = frame.category
        @status = frame.status
        @additional_status = frame.additional_status
      end
    end

    attr_reader :sequence_number, :time_stamp, :data_version, :frames
    def initialize(packet)
      @sequence_number = packet.sequence_number
      @time_stamp = packet.time_stamp
      @data_version = "#{packet.payload.frame_information_data_version.major}.#{packet.payload.frame_information_data_version.minor}"
      @frames = packet.payload.frame_data.map { |f| Frame.new(f) }
    end
  end
end

