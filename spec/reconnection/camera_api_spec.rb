require 'spec_helper'

module SonyCameraRemoteAPI
  describe CameraAPIManager, HDR_AZ1: true do
    let(:cam) { @cam_rcn }
    let(:http) { cam.instance_variable_get(:@api_manager).instance_variable_get(:@http) }
    let(:recon) { cam.instance_variable_get(:@api_manager).
        instance_variable_get(:@retrying).
        instance_variable_get(:@reconnect_by) }
    before do
      cam.change_function_to_shoot 'still', 'Single'
    end

    describe '#method_missing' do
      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stub only once to fail API
          before do
            allow(http).to receive(:post_content) do
              allow(http).to receive(:post_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and execute api' do
            expect(recon).to receive(:call).and_call_original.once
            expect { cam.getShootMode }.to_not raise_error
          end
        end
        context 'permanently' do
          after do
            cam.instance_variable_get(:@api_manager).
                instance_variable_get(:@retrying).
                instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          context "with 'camera' service type API" do
            # Stubs permanently to fail API execution and reconnection
            before do
              cam.instance_variable_get(:@api_manager).
                  instance_variable_get(:@retrying).
                  instance_variable_set(:@reconnect_by, -> { sleep(1); false })
              allow(http).to receive(:post_content).and_raise(HTTPClient::ReceiveTimeoutError)
            end
            it 'gives up to execute API' do
              # Because getAvailableApiList API comes with camera service type API,
              # reconnect_by hook is called twice.
              num_recon = SonyCameraRemoteAPI::Retrying::DEFAULT_RECONNECTION_LIMIT * 2
              expect(recon).to receive(:call).and_call_original.exactly(num_recon).times
              expect { cam.getShootMode }.to raise_error HTTPClient::ReceiveTimeoutError
            end
          end
          context 'with other service type API' do
            # Stubs permanently to fail API execution and reconnection
            before do
              cam.change_function_to_transfer
              cam.instance_variable_get(:@api_manager).
                  instance_variable_get(:@retrying).
                  instance_variable_set(:@reconnect_by, -> { sleep(1); false })
              allow(http).to receive(:post_content).and_raise(HTTPClient::ReceiveTimeoutError)
            end
            it 'gives up to execute API' do
              expect(recon).to receive(:call).and_call_original.
                  exactly(SonyCameraRemoteAPI::Retrying::DEFAULT_RECONNECTION_LIMIT).times
              expect { cam.getSchemeList }.to raise_error HTTPClient::ReceiveTimeoutError
            end
          end
        end
      end
    end


    describe '#getEvent' do
      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stubs to fail API only once
          before do
            allow(http).to receive(:post_async) do
              allow(http).to receive(:post_async).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and execute api' do
            expect(recon).to receive(:call).and_call_original.once
            expect { cam.getEvent(true) }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_get(:@api_manager).
                instance_variable_get(:@retrying).
                instance_variable_set(:@reconnect_by, -> { sleep(1); false })
            allow(http).to receive(:post_async).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          after do
            cam.instance_variable_get(:@api_manager).
                instance_variable_get(:@retrying).
                instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          it 'gives up to execute API' do
            # Reconnection method is called half times to 'camera' service type API
            expect(recon).to receive(:call).and_call_original.
                exactly(SonyCameraRemoteAPI::Retrying::DEFAULT_RECONNECTION_LIMIT).times
            expect { cam.getEvent(true) }.to raise_error HTTPClient::ReceiveTimeoutError
          end

        end
      end
    end
  end
end


