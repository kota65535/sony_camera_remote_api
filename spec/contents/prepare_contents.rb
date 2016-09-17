require 'spec_helper'

module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera, HDR_AZ1: true do
    let(:cam) { @cam }

    describe '#preparing data for contents API tests' do
      it 'generates 210 still images, 10 movie files (6 MP4, 4 XAVCS) for 3 days ( (210+10)*3=660 all)' do

        dates = []
        dates << Time.new(2016, 8, 1).utc.iso8601
        dates << Time.new(2016, 8, 2).utc.iso8601
        dates << Time.new(2016, 8, 3).utc.iso8601

        dates.each do |d|
          # 2nd call of this method always fail!
          # We must restart the camera each time changing date.
          cam.setCurrentTime [{'dateTime' => d,
                               'timeZoneOffsetMinute' => 540,
                               'dstOffsetMinute' => 0}]

          # Create still contents
          cam.change_function_to_shoot 'still', 'Single'
          ($NUM_STILL%10).times do
            cam.capture_still transfer: false
          end
          cam.change_function_to_shoot 'still', 'Burst'
          cam.set_parameter :ContShootingSpeed, '8fps 1sec'
          ($NUM_STILL/10).times do
            cam.capture_still transfer: false
          end


          # Create movie contents
          cam.change_function_to_shoot 'movie'
          cam.set_parameter :MovieFileFormat, 'MP4'
          $NUM_MP4.times do
            cam.start_movie_recording
            sleep 3
            cam.stop_movie_recording
          end
          cam.set_parameter :MovieFileFormat, 'XAVC S'
          $NUM_XAVCS.times do
            cam.start_movie_recording
            sleep 3
            cam.stop_movie_recording
          end

          puts 'Restart camera and press any key...'
          bell_and_getch
          load_and_connect
        end

        # Set current time.
        cam.setCurrentTime [{'dateTime' => Time.now.utc.iso8601,
                             'timeZoneOffsetMinute' => 540,
                             'dstOffsetMinute' => 0}]
      end
    end
  end
end