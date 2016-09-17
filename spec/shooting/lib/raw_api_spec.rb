require 'spec_helper'

module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::RawAPIManager, HDR_AZ1: true, FDR_X1000V: true, ILCE_QX1: true do
    let(:cam) { @cam }
    let(:raw_api) { @cam.instance_variable_get(:@api_manager).instance_variable_get(:@raw_api_manager) }

    describe '#make_api_list' do
      it 'makes API list' do
        # APIs supported by all cameras
        expect(cam.apis).to include(:getShootMode, :getEvent, :getAvailableApiList, :getMethodTypes)
        expect(cam.apis[:getEvent].multi_versions?).to eq true
        expect(cam.apis[:getMethodTypes].multi_service_types?).to eq true
      end
    end
    describe '#search_method' do
      context 'with correct arguments' do
        it 'finds method' do
          service = 'camera'
          id = 5
          version = '1.0'
          expect(raw_api.search_method(:getShootMode, service_type: service, id: id, version: version)).to eq(['getShootMode', service, id, version])
        end
      end
      context 'without arguments' do
        it 'finds method if it can be uniquely determined' do
          expect(raw_api.search_method(:getShootMode)).to eq(['getShootMode', 'camera', 1, '1.0'])
        end
      end

      context 'with invalid version' do
        it 'raises APIVersionInvalid error' do
          expect { raw_api.search_method(:getShootMode, version: '10.0') }.to raise_error(APIVersionInvalid)
          expect { raw_api.search_method(:getEvent, version: '10.0') }.to raise_error(APIVersionInvalid)
        end
      end
      context 'with invalid service type' do
        it 'raises APIVersionInvalid error' do
          expect { raw_api.search_method(:getShootMode, service: 'avContent') }.to raise_error(ServiceTypeInvalid)
          expect { raw_api.search_method(:getMethodTypes, service: 'Hoge') }.to raise_error(ServiceTypeInvalid)
        end
      end

      context 'for method having multiple versions' do
        context 'without version' do
          it 'uses newest version' do
            expect(raw_api.search_method(:getEvent)[3].to_f).to be > 1.0
          end
        end
        context 'with version' do
          it 'uses specified version' do
            expect(raw_api.search_method(:getEvent, version: '1.0')[3]).to eq '1.0'
          end
        end
      end

      context 'for method having multiple service types' do
        context 'without service type' do
          it 'raises ServiceTypeNotGiven error' do
            expect { raw_api.search_method(:getMethodTypes) }.to raise_error(ServiceTypeNotGiven)
          end
        end
        context 'with service type' do
          it 'is successfully called' do
            expect(raw_api.search_method(:getMethodTypes, service: 'avContent')).not_to eq nil
          end
        end
      end

      context 'searched unsupported method' do
        it 'raises APINotSupported error' do
          expect { raw_api.search_method(:getHogeHoge) }.to raise_error(APINotSupported)
        end
      end
    end


    describe '#method_missing' do
      context 'with correct param' do
        it 'successfully calls API and returns response' do
          if cam.getCameraFunction['result'][0] != 'Remote Shooting'
            expect(cam.setCameraFunction(['Remote Shooting'])).to eq('result' => [0], 'id' => 1)
          end
          sleep 2
          expect(cam.setShootMode(['still'], id: 2)).to eq('result' => [0], 'id' => 2)
          # sleep 2
          # expect(cam.actTakePicture['result'][0][0]).to match(%r{http://})
        end
      end
      context 'without param for method requiring it' do
        it 'raises APIExecutionError' do
          expect { cam.setShootMode }.to raise_error(APIExecutionError, /Illegal Argument/)
        end
      end
    end

    describe '#getAvailableApiList' do
      it 'successfully calls API and returns response' do
        expect(cam.getAvailableApiList['result'][0]).to include('getAvailableApiList')
      end
    end

    describe '#getEvent' do
      context 'with param [true]' do
        context 'if camera parameters not changed till timeout' do
          xit 'raises EventTimeoutError' do
            puts 'wait 10 sec for camera to be silent...'
            sleep 10
            expect { cam.getEvent(timeout: 2) }.to raise_error(EventTimeoutError)
          end
        end
        context 'if camera parameters changed' do
          it 'is successfully called and returns response' do
            current, available = cam.getAvailableCameraFunction.result
            size = available.find { |a| a != current }
            cam.setCameraFunction([size])
            expect(cam.getEvent).to include('result')
            cam.setCameraFunction([current])
            expect(cam.getEvent).to include('result')
          end
        end
      end
      context 'with param [false]' do
        it 'is successfully called and returns response' do
          expect(cam.getEvent([false])).to include('result')
        end
      end
    end
  end
end
