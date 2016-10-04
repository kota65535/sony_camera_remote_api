require 'spec_helper'


describe SonyCameraRemoteAPI do
  it 'has a version number' do
    expect(SonyCameraRemoteAPI::VERSION).not_to be nil
  end
end

module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera do
    let(:cam) { @cam }
    before :each do
      FileUtils.rm_r 'images' if Dir.exists? 'images'
      FileUtils.mkdir 'images'
    end
    after :each do
      FileUtils.rm_r 'images' if Dir.exists? 'images'
    end

    describe '#initialize', HDR_AZ1: true  do
      context 'models with system API', HDR_AZ1: true, ILCE_QX1: true do
        it 'gets endpoints' do
          expect(cam.endpoints).to include('camera', 'guide', 'system', 'avContent')
        end
      end
      context 'models without system API', FDR_X1000V: true, DSC_RX100M4: true do
        it 'gets endpoints' do
          expect(cam.endpoints).to include('camera', 'guide', 'avContent')
        end
      end
      it 'makes API list' do
        # APIs supported by all cameras
        expect(cam.apis).to include(:getShootMode, :getEvent, :getAvailableApiList, :getMethodTypes)
        expect(cam.apis[:getEvent].multi_versions?).to eq true
        expect(cam.apis[:getMethodTypes].multi_service_types?).to eq true
      end
    end

    describe '#support?' do
      it 'returns wether it support the API or API group', DSC_RX100M4: true, ILCE_QX1: true do
        expect(cam.support? :getStorageInformation).to eq true
        expect(cam.support? :getAvailableShootMode).to eq true
        expect(cam.support? :ShootMode).to eq true
        expect(cam.support? :getSupportedMovieFileFormat).to eq false
        expect(cam.support? :MovieFileFormat).to eq false
        expect(cam.support? :setWhiteBalance).to be_truthy
        expect(cam.support? :WhiteBalance).to be_truthy
      end
    end
    it 'returns wether it support the API or API group', HDR_AZ1: true do
      expect(cam.support? :getStorageInformation).to eq true
      expect(cam.support? :getAvailableShootMode).to eq true
      expect(cam.support? :ShootMode).to eq true
      expect(cam.support? :getSupportedMovieFileFormat).to eq true
      expect(cam.support? :MovieFileFormat).to eq true
      expect(cam.support? :setWhiteBalance).to eq false
      expect(cam.support? :WhiteBalance).to eq false
    end
      it 'returns wether it support the API or API group', FDR_X1000V: true do
        expect(cam.support? :getStorageInformation).to eq true
        expect(cam.support? :getAvailableShootMode).to eq true
        expect(cam.support? :ShootMode).to eq true
        expect(cam.support? :getSupportedMovieFileFormat).to eq true
        expect(cam.support? :MovieFileFormat).to eq true
        expect(cam.support? :setWhiteBalance).to eq true
        expect(cam.support? :WhiteBalance).to eq true

    end


    describe '#change_function_to_shoot' do
      context 'with Burst shooting mode', HDR_AZ1: true, FDR_X1000V: true do
        it "change camera function to 'Remote Shooting' and wait it completes." do
          cam.change_function_to_shoot 'still', 'Single'
          cam.change_function_to_shoot 'still', 'Burst'
          result = cam.getEvent([false])['result']
          expect(result[21]['currentShootMode']).to eq('still')
          expect(result[38]['contShootingMode']).to eq('Burst')

          cam.change_function_to_shoot 'movie'
          result = cam.getEvent([false])['result']
          expect(result[21]['currentShootMode']).to eq('movie')
        end
      end
      context 'with Countinuous shooting mode', ILCE_QX1: true do
        it "change camera function to 'Remote Shooting' and wait it completes." do
          cam.change_function_to_shoot 'still', 'Single'
          cam.change_function_to_shoot 'still', 'Continuous'
          result = cam.getEvent([false])['result']
          expect(result[21]['currentShootMode']).to eq('still')
          expect(result[38]['contShootingMode']).to eq('Continuous')
        end
      end
      context 'for the model that has mode-dial', DSC_RX100M4: true do
        it 'changes ShootMode if the mode dial is set correctly' do
          set_mode_dial cam, 'still'
          cam.change_function_to_shoot 'still', 'Continuous'
          result = cam.getEvent([false])['result']
          expect(result[38]['contShootingMode']).to eq('Continuous')

          set_mode_dial cam, 'movie'
          cam.change_function_to_shoot 'movie'
          result = cam.getEvent([false])['result']
          expect(result[21]['currentShootMode']).to eq('movie')
        end
        it 'does not change ShootMode and raise IllegalArgument if the mode dial is set incorrectly' do
          set_mode_dial cam, 'movie'
          expect { cam.change_function_to_shoot 'still' }.to raise_error IllegalArgument
        end
      end
    end


    describe '#capture_still', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      let(:dir) { 'images' }
      let(:file) { 'TEST.JPG' }
      before :each do
        set_mode_dial cam, 'still'
      end
      context 'without option' do
        it 'captures single still image and transfer' do
          cam.change_function_to_shoot 'still', 'Single'
          filename = cam.capture_still
          expect(File.exists?(filename)).to be_truthy
        end
      end
      context 'with filename and dir option' do
        it 'captures single still image and transfer by given name' do
          cam.change_function_to_shoot 'still', 'Single'
          filename = cam.capture_still filename: file
          expect(File.exists?(filename)).to be_truthy
        end
        it 'captures single still image and transfer by given name to dir' do
          cam.change_function_to_shoot 'still', 'Single'
          filename = cam.capture_still filename: file, dir: dir
          expect(File.exists?(filename)).to be_truthy
        end
        it 'captures single still image and transfer by given name to dir' do
          cam.change_function_to_shoot 'still', 'Single'
          filename = cam.capture_still dir: dir
          expect(File.exists?(filename)).to be_truthy
        end
      end
      context 'without transfer' do
        it 'captures single still image and saved in camera storage' do
          cam.change_function_to_shoot 'still', 'Single'
          cam.capture_still transfer: false
        end
      end
    end


    describe '#capture_still in Burst shooting mode', HDR_AZ1: true, FDR_X1000V: true do
      let(:dir) { 'images' }
      let(:prefix) { 'TEST' }
      context 'without transfer' do
        it 'captures still images' do
          cam.change_function_to_shoot 'still', 'Burst'
          cam.capture_still
        end
      end
      context 'with trasfer option' do
        it 'captures 10 still images and transfer all' do
          cam.change_function_to_shoot 'still', 'Burst'
          filenames = cam.capture_still transfer: true
          expect(Dir['*'] & filenames).to match_array(filenames)
        end
        context 'with prefix option' do
          it 'captures 10 still image and transfer all by prefixed seqencial filenames' do
            cam.change_function_to_shoot 'still', 'Burst'
            filenames = cam.capture_still transfer: true, prefix: prefix
            expect(Dir['*'] & filenames).to match_array(filenames)
          end
        end
        context 'with dir option' do
          it 'captures 10 still images and transfer them to dir' do
            cam.change_function_to_shoot 'still', 'Burst'
            filenames = cam.capture_still transfer: true, dir: dir
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
        end
        context 'with prefix and dir option' do
          it 'captures 10 still image and transfer all by prefixed seqencial filenames to dir' do
            cam.change_function_to_shoot 'still', 'Burst'
            filenames = cam.capture_still transfer: true, prefix: prefix, dir: dir
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
        end
      end
    end


    describe '#continuous_shooting', DSC_RX100M4: true, ILCE_QX1: true do
      let(:dir) { 'images' }
      let(:prefix) { 'TEST' }
      before :each do
        cam.change_function_to_shoot 'still', 'Continuous'
      end
      context 'with no option' do
        it 'performs continuous shooting' do
          cam.start_continuous_shooting
          sleep 1.5
          cam.stop_continuous_shooting
          cam.change_function_to_shoot 'still', 'Spd Priority Cont.'
          cam.start_continuous_shooting
          sleep 1.5
          cam.stop_continuous_shooting
        end
      end
      context 'with trasfer' do
        context 'without filename' do
          it 'records still images by the interval and transfer all' do
            cam.start_continuous_shooting
            sleep 1.5
            filenames = cam.stop_continuous_shooting(transfer: true)
            expect(Dir['*'] & filenames).to match_array(filenames)
          end
        end
        context 'with filename' do
          it 'records still images by the interval and save them with prefixed sequencial filenames' do
            cam.start_continuous_shooting
            sleep 1.5
            filenames = cam.stop_continuous_shooting(transfer: true, prefix: prefix)
            expect(Dir['*'] & filenames).to match_array(filenames)
          end
          it 'records still images by the interval and save them to dir' do
            cam.start_continuous_shooting
            sleep 1
            filenames = cam.stop_continuous_shooting(transfer: true, dir: dir)
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
          it 'records still images by the interval and save them with prefixed sequencial filenames to dir' do
            cam.start_continuous_shooting
            sleep 1
            filenames = cam.stop_continuous_shooting(transfer: true, prefix: prefix, dir: dir)
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
        end
      end
    end


    describe '#movie_recording', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      let(:dir) { 'images' }
      let(:file) { 'TEST.MP4' }
      before :each do
        set_mode_dial cam, 'movie'
      end
      context 'with no option' do
        it 'records movie' do
          cam.change_function_to_shoot 'movie'
          cam.start_movie_recording
          sleep 3
          cam.stop_movie_recording
        end
      end
      context 'with trasfer' do
        it 'records and transfer movie' do
          cam.change_function_to_shoot 'movie'
          cam.start_movie_recording
          sleep 1
          filename = cam.stop_movie_recording(transfer: true)
          expect(File.exists?(filename)).to be_truthy
        end
        context 'with filename option' do
          it 'records movie and save as given filename' do
            cam.change_function_to_shoot 'movie'
            cam.start_movie_recording
            sleep 1
            filename = cam.stop_movie_recording(transfer: true, filename: file)
            expect(File.exists?(filename)).to be_truthy
          end
        end
        context 'with dir option' do
          it 'records and transfer movie to dir' do
            cam.change_function_to_shoot 'movie'
            cam.start_movie_recording
            sleep 1
            filename = cam.stop_movie_recording(transfer: true, dir: dir)
            expect(File.exists?(filename)).to be_truthy
          end
        end
        context 'with filename and dir option' do
          it 'records and transfer movie by given filename to dir' do
            cam.change_function_to_shoot 'movie'
            cam.start_movie_recording
            sleep 1
            filename = cam.stop_movie_recording(transfer: true, filename: file, dir: dir)
            expect(File.exists?(filename)).to be_truthy
          end
        end
      end
    end


    describe '#interval_recording', HDR_AZ1: true, FDR_X1000V: true do
      let(:dir) { 'images' }
      let(:prefix) { "TEST" }
      context 'with no option' do
        it 'performs interval still recording' do
          cam.change_function_to_shoot 'intervalstill'
          cam.start_interval_recording
          sleep 1
          cam.stop_interval_recording
        end
      end
      context 'with trasfer' do
        context 'without filename' do
          it 'records still images by the interval and transfer all' do
            cam.change_function_to_shoot 'intervalstill'
            cam.start_interval_recording
            sleep 1
            filenames = cam.stop_interval_recording(transfer: true)
            expect(Dir['*'] & filenames).to match_array(filenames)
          end
        end
        context 'with filename' do
          it 'records still images by the interval and save them with prefixed sequencial filenames' do
            cam.change_function_to_shoot 'intervalstill'
            cam.start_interval_recording
            sleep 1
            filenames = cam.stop_interval_recording(transfer: true, prefix: prefix)
            expect(Dir['*'] & filenames).to match_array(filenames)
          end
          it 'records still images by the interval and save them to dir' do
            cam.change_function_to_shoot 'intervalstill'
            cam.start_interval_recording
            sleep 1
            filenames = cam.stop_interval_recording(transfer: true, dir: dir)
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
          it 'records still images by the interval and save them with prefixed sequencial filenames to dir' do
            cam.change_function_to_shoot 'intervalstill'
            cam.start_interval_recording
            sleep 1
            filenames = cam.stop_interval_recording(transfer: true, prefix: prefix, dir: dir)
            expect(Dir["#{dir}/*"] & filenames).to match_array(filenames)
          end
        end
      end
    end


    describe '#loop_recording', FDR_X1000V: true do
      let(:dir) { 'images' }
      let(:file) { 'TEST.MP4' }
      context 'with no option' do
        it 'records movie' do
          cam.change_function_to_shoot 'looprec'
          cam.start_loop_recording
          sleep 3
          cam.stop_loop_recording
        end
      end
      context 'with trasfer' do
        it 'records and transfer movie' do
          cam.change_function_to_shoot 'looprec'
          cam.start_loop_recording
          sleep 1
          filename = cam.stop_loop_recording(transfer: true)
          expect(File.exists?(filename)).to be_truthy
        end
        context 'with filename option' do
          it 'records movie and save as given filename' do
            cam.change_function_to_shoot 'looprec'
            cam.start_loop_recording
            sleep 1
            filename = cam.stop_loop_recording(transfer: true, filename: file)
            expect(File.exists?(filename)).to be_truthy
          end
        end
        context 'with dir option' do
          it 'records and transfer movie to dir' do
            cam.change_function_to_shoot 'looprec'
            cam.start_loop_recording
            sleep 1
            filename = cam.stop_loop_recording(transfer: true, dir: dir)
            expect(File.exists?(filename)).to be_truthy
          end
        end
        context 'with filename and dir option' do
          it 'records and transfer movie by given filename to dir' do
            cam.change_function_to_shoot 'looprec'
            cam.start_loop_recording
            sleep 1
            filename = cam.stop_loop_recording(transfer: true, filename: file, dir: dir)
            expect(File.exists?(filename)).to be_truthy
          end
        end
      end
    end


    describe '#start_liveview_thread' do
      let(:dir) { 'liveview' }
      before :each do
        FileUtils.rm_r 'liveview' if Dir.exists? 'liveview'
        FileUtils.mkdir_p 'liveview'
      end
      after :each do
        FileUtils.rm_r 'liveview' if Dir.exists? 'liveview'
      end
      context 'with time option', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
        it 'starts streaming and finishes after 5 seconds' do
          th = cam.start_liveview_thread(time: 5) do |img, info|
            filename = "#{img.sequence_number}.jpg"
            path = File.join dir, filename
            File.write path, img.jpeg_data
            puts "Wrote: #{path}."
          end
          th.join
          # expect(Dir["#{dir}/*.jpg"]).to be > 10
        end
      end
      context 'with size option', DSC_RX100M4: true do
        it 'starts streaming with specified liveview size' do
          th = cam.start_liveview_thread(size: 'M') do |img, info|
            filename = "#{img.sequence_number}.jpg"
            path = File.join dir, filename
            File.write path, img.jpeg_data
            puts "Wrote: #{path}."
          end
          loop do
            break if Dir["#{dir}/*.jpg"].size > 10
            sleep 1
          end
          th.kill
          expect(Dir["#{dir}/*.jpg"].size).to be > 10
        end
      end
      xcontext 'with liveview frame info', ILCE_QX1: true do
        # This test is merged with #act_tracking_focus test.
      end
    end
  end
end
