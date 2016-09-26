require 'spec_helper'

module SonyCameraRemoteAPI
  describe CameraAPIManager, HDR_AZ1: true do
    let(:cam) { @cam_rcn }
    let(:cli) { cam.instance_variable_get(:@api_manager).instance_variable_get(:@raw_api_manager).instance_variable_get(:@cli) }
    let(:hook) { cam.instance_variable_get(:@api_manager).instance_variable_get(:@reconnect_by) }
    before do
      cam.change_function_to_shoot 'still', 'Single'
    end

    describe '#method_missing' do
      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stub only once to fail API
          before do
            allow(cli).to receive(:post_content) do
              allow(cli).to receive(:post_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and call api' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.getShootMode }.to_not raise_error
          end
        end
        context 'permanently' do
          context "with 'camera' service type API" do
            # Stubs permanently to fail API execution and reconnection
            before do
              cam.instance_variable_get(:@api_manager).instance_variable_set(:@reconnect_by, -> { sleep(1); false })
              allow(cli).to receive(:post_content).and_raise(HTTPClient::ReceiveTimeoutError)
            end
            it 'gives up to execute API' do
              # Because getAvailableApiList API comes with camera service type API,
              # reconnect_by hook is called twice.
              expect(hook).to receive(:call).and_call_original.twice
              expect { cam.getShootMode }.to raise_error HTTPClient::ReceiveTimeoutError
            end
          end
          after do
            cam.instance_variable_get(:@api_manager).instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          context 'with other service type API' do
            # Stubs permanently to fail API execution and reconnection
            before do
              cam.change_function_to_transfer
              cam.instance_variable_get(:@api_manager).instance_variable_set(:@reconnect_by, -> { sleep(1); false })
              allow(cli).to receive(:post_content).and_raise(HTTPClient::ReceiveTimeoutError)
            end
            it 'gives up to execute API' do
              expect(hook).to receive(:call).and_call_original.once
              expect { cam.getSchemeList }.to raise_error HTTPClient::ReceiveTimeoutError
            end
          end
        end
      end
    end


    describe '#getEvent' do
      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stub only once to fail API
          before do
            allow(cli).to receive(:post_async) do
              allow(cli).to receive(:post_async).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and call api' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.getEvent(true) }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_get(:@api_manager).instance_variable_set(:@reconnect_by, -> { sleep(1); false })
            allow(cli).to receive(:post_async).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          it 'gives up to execute API' do
            # getAvailableApiList API does not come with getEvent, so reconnect_by hook is called once.
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.getEvent(true) }.to raise_error HTTPClient::ReceiveTimeoutError
          end
        end
        after do
          cam.instance_variable_get(:@api_manager).instance_variable_set(:@reconnect_by, @shelf.method(:connect))
        end
      end
    end
  end
end


