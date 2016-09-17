require 'spec_helper'


module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::CameraAPIGroupManager do
    let(:cam) { @cam }
    let(:max_num_values) { 5 }

    shared_examples_for 'API group' do | group, shoot_mode, exposure_mode |
      before do
        set_mode_dial cam, shoot_mode, exposure_mode
      end
      context 'with invalid argment' do
        it 'raises InvalidArgument error and does not change setting' do
          expect_any_instance_of(CameraAPIGroupManager::APIGroup).to_not receive(:set_value)
          expect { cam.set_parameter group, '!!!!' }.to raise_error(IllegalArgument).and not_change { cam.get_parameter(group)[:current] }
        end
      end
      context 'with the same value to current' do
        it 'does not change setting' do
          expect_any_instance_of(CameraAPIGroupManager::APIGroup).to_not receive(:set_value)
          current = cam.get_current(group)
          expect { cam.set_parameter group, current }.to_not change { cam.get_current(group) }
        end
      end
      context 'with available values' do
        it 'changes setting and call set API once each' do
          # Get available values
          result = cam.get_parameter group
          expect(result[:available].size).to be > 0
          # Finish if no other value is available
          next if result[:available].size == 1

          # Delete current value
          candidates = result[:available].delete_if { |r| r == result[:current] }
          if max_num_values < candidates.size
            step_size = candidates.size / max_num_values + 1
            candidates = (0..candidates.size-1).step(step_size).map { |i| candidates[i] }
            puts "Decreased variation: step_size = #{step_size}"
          end
          candidates += [result[:current]]

          expect_any_instance_of(CameraAPIGroupManager::APIGroup).to receive(:set_value).exactly(candidates.size).times.and_call_original

          # Iterate for all available values
          current = result[:current]
          candidates.each do |v|
            cam.log.info "value: #{v}"
            expect { cam.set_parameter(group, v) }.to change { cam.get_current(group) }.from(current).to(v)
            current = v
            sleep 3
          end
        end
      end
    end



    describe '#Shoot mode', HDR_AZ1: true, FDR_X1000V: true, ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :ShootMode
      end
    end

    # TODO: temporally skip when ILCE_QX1
    describe '#Zoom setting', ILCE_7: true, DSC_RX100M4: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :ZoomSetting
      end
    end

    describe '#Tracking focus', ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :TrackingFocus, 'still'
      end
    end

    describe '#Continuous shooting mode', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :ContShootingMode, 'still'
      end
    end

    # Oh fuck! DSC-RX100M4 supports this API group but NEVER be available!!!!
    describe '#Continuous shooting speed', HDR_AZ1: true, FDR_X1000V: true do
      context 'with Continuous shooting mode other than "Single"' do
        before do
          cam.change_function_to_shoot 'still'
          result = cam.get_parameter :ContShootingMode
          if result[:current] == 'Single'
            result[:available].delete 'Single'
            cam.change_function_to_shoot 'still', result[:available][0]
          end
        end
        it_behaves_like 'API group', :ContShootingSpeed
      end
    end

    describe '#Self-timer', HDR_AZ1: true, FDR_X1000V: true, ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :SelfTimer, 'still'
      end
    end

    describe '#Exposure mode' do
      context 'with any ShootMode', ILCE_QX1: true do
        it_behaves_like 'API group', :ExposureMode
      end
      context 'with its ShootMode "movie"', DSC_RX100M4: true do
        it_behaves_like 'API group', :ExposureMode, 'movie'
      end
    end

    describe '#Focus mode' do
      context 'with any ShootMode', DSC_RX100M4: true, ILCE_QX1: true do
        it_behaves_like 'API group', :FocusMode
      end
    end

    # Exposure mode should be P.A.S.M.
    # This API group is not available in Intelligent Auto and Superior Auto mode, for example.
    describe '#Exposure compensation'do
      context 'with any ShootMode', FDR_X1000V: true, ILCE_7: true do
        it_behaves_like 'API group', :ExposureCompensation
      end
      context 'with its ShootMode "still" and ExposureMode "P,A,S,M"', DSC_RX100M4: true, ILCE_QX1: true do
        it_behaves_like 'API group', :ExposureCompensation, 'still', 'Program Auto'
      end
    end

    describe '#F number' do
      context 'with its ShootMode "still" and ExposureMode "Aperture"', ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
        it_behaves_like 'API group', :FNumber, 'still', 'Aperture'
      end
    end

    describe '#Shutter speed' do
      context 'with its ShootMode "still" and ExposureMode "Shutter"', ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
        it_behaves_like 'API group', :ShutterSpeed, 'still', 'Shutter'
      end
    end

    describe '#ISO speed rate', ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :IsoSpeedRate, 'still'
      end
    end

    # FDR_X1000V accepts only Auto WB mode and returns empty array as available modes, so skip it.
    describe '#White balance', ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
      let(:group) { :WhiteBalance }
      context 'for other than "Color Temperature" mode' do
        context 'with available mode' do
          it 'changes setting and call set API once each' do
            # Get available values
            result = cam.get_parameter group
            expect(result[:available].size).to be > 0

            # Exclude Color Temperature and current mode
            result[:available].delete_if { |r| r['whiteBalanceMode'] == 'Color Temperature' }
            result[:available].delete_if { |r| r == result[:current] }
            candidates = result[:available]

            # Finish if no other value is available
            next if candidates.size <= 1

            expect_any_instance_of(CameraAPIGroupManager::APIGroup).to receive(:set_value).exactly(candidates.size*2).times.and_call_original

            # Iterate all but 'Color Temperature mode' by giving Hash as parameter
            current = result[:current]['whiteBalanceMode']
            candidates.each do |v|
              cam.log.info "value: #{v}"
              expect { cam.set_parameter(group, v) }.to change { cam.get_parameter(group)[:current]['whiteBalanceMode'] }.from(current).to(v['whiteBalanceMode'])
              current = v['whiteBalanceMode']
            end

            # Iterate all but 'Color Temperature mode' by giving Array as parameter
            candidates_array = candidates.map { |c| [ c['whiteBalanceMode'], false, 0] }
            candidates_array.each do |v|
              cam.log.info "value: #{v}"
              expect { cam.set_parameter(group, v) }.to change { cam.get_parameter(group)[:current]['whiteBalanceMode'] }.from(current).to(v[0])
              current = v[0]
            end
          end
        end
      end
      context 'for "Color Temperature" mode' do
        context 'with available temperature value' do
          it 'changes setting and call set API once each ' do
            # Skip if 'Color Temperature' mode is not available
            result = cam.get_parameter group
            mode = result[:available].find { |r| r['whiteBalanceMode'] == 'Color Temperature' }
            next if mode.nil?

            # Set the first available temperature value as initial
            param = { 'whiteBalanceMode' => 'Color Temperature',
                       'colorTemperature' => mode['colorTemperature'][0] }
            result = cam.set_parameter group, param
            expect(result[:current]).to eq param

            # Temperature candidates (every three)
            candidates = mode['colorTemperature'][1..-1] + [mode['colorTemperature'][0]]
            if max_num_values < candidates.size
              step_size = candidates.size / max_num_values + 1
              candidates = (0..candidates.size-1).step(step_size).map { |i| candidates[i] }
              puts "Decreased variation: step_size = #{step_size}"
            end

            expect_any_instance_of(CameraAPIGroupManager::APIGroup).to receive(:set_value).exactly(candidates.size).times.and_call_original

            # Iterate every three temperature values
            current = mode['colorTemperature'][0]
            candidates.each do |v|
              param = {'whiteBalanceMode' => 'Color Temperature', 'colorTemperature' => v }
              cam.log.info "value: #{v}"
              expect { cam.set_parameter(group, param) }.to change { cam.get_parameter(group)[:current]['colorTemperature'] }.from(current).to(v)
              current = v
            end
          end
        end
      end
    end

    # Cameras with internal pop-up flash light should be poped-up.
    describe '#Flash mode' do
      context 'with its ShootMode "still"', DSC_RX100M4: true, ILCE_QX1: true do
        it_behaves_like 'API group', :FlashMode, 'still'
      end
      xcontext 'with its ShootMode "still"', ILCE_7: true do
        before :all do
          puts 'Set external flash light and press any key...'
          bell_and_getch
        end
        it_behaves_like 'API group' do
          let(:group) { :FlashMode }
        end
      end
    end

    describe '#Still size', ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :StillSize, 'still'
      end
    end

    describe '#Still quality', ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :StillQuality, 'still'
      end
    end

    describe '#Postview image size', HDR_AZ1: true, FDR_X1000V: true, ILCE_7: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :PostviewImageSize, 'still'
      end
    end

    describe '#Movie file format', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :MovieFileFormat, 'movie'
      end
    end

    describe '#Movie quality', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :MovieQuality, 'movie'
      end
    end

    describe '#Steady mode', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :SteadyMode, 'movie'
      end
    end
    #
    describe '#View angle', FDR_X1000V: true do
      context 'with its ShootMode "still"' do
        it_behaves_like 'API group', :ViewAngle, 'still'
      end
    end

    describe '#Scene selection', HDR_AZ1: true, FDR_X1000V: true do
      it_behaves_like 'API group', :SceneSelection
    end

    describe '#Color setting', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :ColorSetting, 'movie'
      end
    end

    describe '#Interval time', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "intervalstill"' do
        it_behaves_like 'API group', :IntervalTime, 'intervalstill'
      end
    end

    describe '#Loop recording time', FDR_X1000V: true do
      context 'with its ShootMode "looprec"' do
        it_behaves_like 'API group', :LoopRecTime, 'looprec'
      end
    end

    describe '#Wind noise reduction', FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :WindNoiseReduction
      end
    end

    describe '#Audio recording setting', FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :AudioRecording
      end
    end

    describe '#Flip setting', HDR_AZ1: true, FDR_X1000V: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :FlipSetting
      end
    end

    # TODO: This test make camera restart, so skip it temporally
    xdescribe '#TV color system', HDR_AZ1: true, FDR_X1000V: true do
      context 'with its ShootMode "movie"' do
        it_behaves_like 'API group', :TvColorSystem, 'movie'
      end
    end

    describe '#Camera function', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :CameraFunction
      end
    end

    describe '#IR remote control', HDR_AZ1: true, FDR_X1000V: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :InfraredRemoteControl
      end
    end

    describe '#Auto power off', HDR_AZ1: true, FDR_X1000V: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :AutoPowerOff
      end
    end

    describe '#Beep mode', HDR_AZ1: true, FDR_X1000V: true, ILCE_QX1: true do
      context 'with any ShootMode' do
        it_behaves_like 'API group', :BeepMode
      end
    end
  end
end