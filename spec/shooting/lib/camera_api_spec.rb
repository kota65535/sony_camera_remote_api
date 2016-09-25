require 'spec_helper'

module SonyCameraRemoteAPI
  describe CameraAPIManager do
    let(:cam) { @cam }
    let(:shoot_mode) do
      case @model_tag
        when 'FDR_X1000V'
          ['still', 'movie', 'intervalstill', 'looprec']
        when 'HDR_AZ1'
          ['still', 'movie', 'intervalstill']
      end
    end
    describe '#get_parameter' do
      context 'with general parameters', HDR_AZ1: true, FDR_X1000V: true do
        context 'which are available' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter :ShootMode, 'still'
          end
          it 'gets supported/available/current value of the parameter' do
            result = cam.get_parameter :CameraFunction
            expect(result[:available]).to match_array ['Contents Transfer', 'Remote Shooting']
            expect(result[:supported]).to match_array ['Contents Transfer', 'Remote Shooting']
            expect(result[:current]).to eq 'Remote Shooting'

            result = cam.get_parameter :ShootMode

            expect(result[:available]).to match_array shoot_mode
            expect(result[:supported]).to match_array shoot_mode
            expect(result[:current]).to eq 'still'
          end
        end
        context 'which are unsupported' do
          it 'raises APINotSupported error immediately' do
            expect { cam.get_parameter :CameraHoge }.to raise_error APINotSupported
          end
        end
        context 'which are not unavailable' do
          it 'raises APINotAvailable error after a few seconds' do
            cam.set_parameter :CameraFunction, 'Contents Transfer'
            expect { cam.get_parameter :ShootMode }.to raise_error APINotAvailable
          end
        end
      end
      context 'with hardware-affected parameters', DSC_RX100M4: true do
        before do
          set_mode_dial cam, 'still', 'Program Auto'
        end
        it 'tries to get supported/available/current values but it can get only current value' do
          result = cam.get_parameter :ExposureMode
          expect(result[:available]).to eq nil
          expect(result[:supported]).to eq nil
          expect(result[:current]).to eq 'Program Auto'
        end
      end
    end

    describe '#get_parameter!' do
      context 'with general parameters', HDR_AZ1: true, FDR_X1000V: true do
        context 'which are available' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter :ShootMode, 'still'
          end
          it 'gets supported/available/current value of the parameter' do
            result = cam.get_parameter! :CameraFunction
            expect(result[:available]).to match_array ['Contents Transfer', 'Remote Shooting']
            expect(result[:supported]).to match_array ['Contents Transfer', 'Remote Shooting']
            expect(result[:current]).to eq 'Remote Shooting'

            result = cam.get_parameter! :ShootMode
            expect(result[:available]).to match_array shoot_mode
            expect(result[:supported]).to match_array shoot_mode
            expect(result[:current]).to eq 'still'
          end
        end
        context 'which are unsupported' do
          it 'gets nil supported/available/current values' do
            result = cam.get_parameter! :CameraHoge
            expect(result[:available]).to eq nil
            expect(result[:supported]).to eq nil
            expect(result[:current]).to eq nil
          end
        end
        context 'which are unavailable' do
          before do
            cam.set_parameter :CameraFunction, 'Contents Transfer'
          end
          it 'gets nil supported/available/current values after a few seconds' do
            result = cam.get_parameter! :ShootMode
            expect(result[:available]).to eq nil
            expect(result[:supported]).to eq nil
            expect(result[:current]).to eq nil
          end
        end
      end
    end

    describe '#get_current' do
      context 'with general parameters', HDR_AZ1: true, FDR_X1000V: true do
        context 'which are available' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter :ShootMode, 'still'
          end
          it 'gets current value of the parameter' do
            result = cam.get_current :CameraFunction
            expect(result).to eq 'Remote Shooting'

            result = cam.get_current :ShootMode
            expect(result).to eq 'still'
          end
        end
      end
      context 'with hardware-affected parameters', DSC_RX100M4: true do
        before do
          set_mode_dial cam, 'still', 'Program Auto'
        end
        it 'gets current values' do
          result = cam.get_current :ExposureMode
          expect(result).to eq 'Program Auto'
        end
      end
    end


    describe '#set_parameter' do
      context 'with general parameters', HDR_AZ1: true, FDR_X1000V: true do
        context 'which are available' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter :ShootMode, 'still'
          end
          context 'with different value to current' do
            it 'sets parameter and return current/available/old values' do
              result = cam.set_parameter :ShootMode, 'movie'
              expect(result[:current]).to eq 'movie'
              expect(result[:available]).to match_array shoot_mode
              expect(result[:old]).to eq 'still'
            end
          end
          context 'with the same value to current' do
            it 'does not set parameter and return current value' do
              result = cam.set_parameter :CameraFunction, 'Remote Shooting'
              expect(result[:current]).to eq 'Remote Shooting'
              expect(result[:available]).to eq nil
              expect(result[:old]).to eq nil
            end
          end
        end
        context 'which are unsupported' do
          it 'raises APINotSupported error' do
            expect { cam.set_parameter :CameraHoge, 'hogehoge' }.to raise_error(APINotSupported)
            expect { cam.set_parameter nil, 'hogehoge' }.to raise_error(APINotSupported)
          end
        end
        context 'which are unavailable' do
          before do
            cam.set_parameter :CameraFunction, 'Contents Transfer'
          end
          it 'raises APINotAvailable error' do
            expect { cam.set_parameter :ShootMode, 'still' }.to raise_error(APINotAvailable)
            expect { cam.set_parameter :ShootMode, nil }.to raise_error(APINotAvailable)
          end
        end
        context 'which are available but with unavailable value' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
          end
          it 'raises IllegalArgument error' do
            expect { cam.set_parameter :ShootMode, 'hogehoge' }.to raise_error(IllegalArgument)
            expect { cam.set_parameter :ShootMode, nil }.to raise_error(IllegalArgument)
          end
        end
      end
      context 'with hardware-affected parameters', DSC_RX100M4: true do
        before do
          set_mode_dial cam, 'still', 'Program Auto'
        end
        context 'with different value to current' do
          it 'raises APINotAvailable error ' do
            expect { cam.set_parameter :ExposureMode, 'Aperture' }.to raise_error APINotAvailable
          end
        end
        context 'with the same value to current' do
          it 'does not set parameter and return current value' do
            result = cam.set_parameter :ExposureMode, 'Program Auto'
            expect(result[:current]).to eq 'Program Auto'
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
          end
        end
      end
    end


    describe '#set_parameter!' do
      context 'with general parameters', HDR_AZ1: true, FDR_X1000V: true do
        context 'which are available' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter :ShootMode, 'still'
          end
          context 'with different value to current' do
            it 'sets parameter and return current/available/old values' do
              result = cam.set_parameter! :ShootMode, 'movie'
              expect(result[:current]).to eq 'movie'
              expect(result[:available]).to match_array shoot_mode
              expect(result[:old]).to eq 'still'
            end
          end
          context 'with the same value to current' do
            it 'does not set parameter and return current value' do
              result = cam.set_parameter! :CameraFunction, 'Remote Shooting'
              expect(result[:current]).to eq 'Remote Shooting'
              expect(result[:available]).to eq nil
              expect(result[:old]).to eq nil
            end
          end
        end
        context 'which are unsupported' do
          it 'does not set parameter and return nil current/availablecurrent/old values' do
            result = cam.set_parameter! :CameraHoge, 'hogehoge'
            expect(result[:current]).to eq nil
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
            result = cam.set_parameter! nil, 'hogehoge'
            expect(result[:current]).to eq nil
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
          end
        end
        context 'which are unavailable' do
          before do
            cam.set_parameter :CameraFunction, 'Contents Transfer'
          end
          it 'does not set parameter and return nil current/availablecurrent/old values' do
            result = cam.set_parameter! :ShootMode, 'still'
            expect(result[:current]).to eq nil
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
            result = cam.set_parameter! :ShootMode, nil
            expect(result[:current]).to eq nil
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
          end
        end
        context 'which are available but with unavailable value' do
          before do
            cam.set_parameter :CameraFunction, 'Remote Shooting'
            cam.set_parameter! :ShootMode, 'still'
          end
          it 'does not set parameter and return current/available/old values' do
            result = cam.set_parameter! :ShootMode, 'hogehoge'
            expect(result[:current]).to eq 'still'
            expect(result[:available]).to match_array  shoot_mode
            expect(result[:old]).to eq nil
            result = cam.set_parameter! :ShootMode, nil
            expect(result[:current]).to eq 'still'
            expect(result[:available]).to match_array  shoot_mode
            expect(result[:old]).to eq nil
          end
        end
      end
      context 'with hardware-affected parameters', DSC_RX100M4: true do
        before do
          set_mode_dial cam, 'still', 'Program Auto'
        end
        context 'with the same value to current' do
          it 'does not set parameter and return current value' do
            result = cam.set_parameter! :ExposureMode, 'Aperture'
            expect(result[:current]).to eq 'Program Auto'
            expect(result[:available]).to eq nil
            expect(result[:old]).to eq nil
          end
        end
      end
    end

    describe '#wait_event', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      before do
        cam.set_parameter :CameraFunction, 'Remote Shooting'
      end
      context 'without option' do
        context 'with correct block' do
          it 'waits until desired parameter change' do
            # getEvent(true) is called at least 0 times.
            allow_any_instance_of(CameraAPIManager).to receive(:getEvent).with(true, anything).and_call_original
            expect_any_instance_of(CameraAPIManager).to receive(:getEvent).with(false, anything).once.and_call_original
            cam.setCameraFunction ['Contents Transfer']
            expect(cam.wait_event  { |r| r[12]['currentCameraFunction'] == 'Contents Transfer' }[12]['currentCameraFunction']).to eq 'Contents Transfer'
          end
          it 'returns immediately if the parameter is already the desired value' do
            expect_any_instance_of(CameraAPIManager).to_not receive(:getEvent).with(true, anything)
            expect_any_instance_of(CameraAPIManager).to receive(:getEvent).with(false, anything).once.and_call_original
            expect(cam.wait_event  { |r| r[12]['currentCameraFunction'] == 'Remote Shooting' }[12]['currentCameraFunction']).to eq 'Remote Shooting'
          end
        end
        context 'with broken block' do
          it 'raises EventTimeoutError after default timeout expired' do
            cam.setCameraFunction ['Contents Transfer']
            expect { cam.wait_event { |r| r[15]['cameraFunctionResult'] == 'HogeHoge' } }.to raise_error EventTimeoutError
          end
          it 'raises EventTimeoutError after specified timeout expired' do
            expect { cam.wait_event(timeout: 3) { |r| r[15]['cameraFunctionResult'] == 'HogeHoge' } }.to raise_error EventTimeoutError
          end
        end
      end
      context 'with long_polling true' do
        context 'with correct block' do
          it 'waits until desired parameter changes' do
            expect_any_instance_of(CameraAPIManager).to receive(:getEvent).with(true, anything).at_least(:once).and_call_original
            expect_any_instance_of(CameraAPIManager).to_not receive(:getEvent).with(false, anything)
            cam.setCameraFunction ['Contents Transfer']
            expect(cam.wait_event(polling: true) { |r| r[12]['currentCameraFunction'] == 'Contents Transfer' }[12]['currentCameraFunction']).to eq 'Contents Transfer'
          end
          context 'if the parameter is already the desired value' do
            it 'raises EventTimeoutError after default timeout expired ' do
              expect {cam.wait_event(polling: true) { |r| r[12]['currentCameraFunction'] == 'Contents Transfer' } }.to raise_error EventTimeoutError
            end
          end
        end
      end
      context 'with long_polling false' do
        context 'with correct block' do
          it 'waits until desired parameter changes' do
            # The default stub is needed when you want stub method for only specific arguments
            expect_any_instance_of(CameraAPIManager).to_not receive(:getEvent).with(true, anything)
            expect_any_instance_of(CameraAPIManager).to receive(:getEvent).with(false, anything).at_least(:once).and_call_original
            cam.setCameraFunction ['Contents Transfer']
            expect(cam.wait_event(polling: false) { |r| r[12]['currentCameraFunction'] == 'Contents Transfer' }[12]['currentCameraFunction']).to eq 'Contents Transfer'
          end
          context 'if the parameter is already the desired value' do
            it 'returns immediately if the parameter is already the desired value' do
              expect(cam.wait_event(polling: false) { |r| r[12]['currentCameraFunction'] == 'Remote Shooting' }[12]['currentCameraFunction']).to eq 'Remote Shooting'
            end
          end
        end
      end
    end
  end
end
