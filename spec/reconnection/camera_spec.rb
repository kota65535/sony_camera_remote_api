require 'spec_helper'


module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera, HDR_AZ1: true do
    let(:cam) { @cam_rcn }
    let(:cli)  { cam.instance_variable_get(:@cli) }
    let(:hook) { cam.instance_variable_get(:@reconnect_by) }
    before :each do
      FileUtils.rm_r 'images' if Dir.exists? 'images'
      FileUtils.mkdir 'images'
    end
    after :each do
      FileUtils.rm_r 'images' if Dir.exists? 'images'
    end


    describe '#capture_still' do
      before do
        cam.change_function_to_shoot 'still', 'Single'
      end
      after do
        cam.change_function_to_transfer
        content = cam.get_content_list type: 'still', count: 1
        cam.delete_contents content
      end

      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stub only once to fail API
          before do
            allow(cli).to receive(:get_content) do
              allow(cli).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and call api' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.capture_still }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_set(:@reconnect_by, -> { false })
            allow(cli).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          it 'gives up to execute and raise error' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.capture_still }.to raise_error HTTPClient::ReceiveTimeoutError
          end
          after do
            cam.instance_variable_set(:@reconnect_by, method(:load_and_connect))
          end
        end
      end
    end

    describe '#transfer_contents' do
      before do
        cam.change_function_to_transfer
      end

      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stub only once to fail API
          before do
            allow(cli).to receive(:get_content) do
              allow(cli).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and call api' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.transfer_contents(cam.get_content_list(type: 'still', count: 1)) }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_set(:@reconnect_by, -> { false })
            allow(cli).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          it 'gives up to execute and raise error' do
            expect(hook).to receive(:call).and_call_original.once
            expect { cam.transfer_contents(cam.get_content_list(type: 'still', count: 1)) }.to raise_error HTTPClient::ReceiveTimeoutError
          end
          after do
            cam.instance_variable_set(:@reconnect_by, method(:load_and_connect))
          end
        end
      end
    end

    describe '#start_liveview_thread' do
      before do
        cam.change_function_to_shoot 'still', 'Single'
      end

      context 'with its connection disconnected' do
        context 'temporarily' do
          # Stubs only once
          before do
            allow(cli).to receive(:get_content) do
              allow(cli).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and call api' do
            expect(hook).to receive(:call).and_call_original.at_least(:once)
            expect do
              th = cam.start_liveview_thread
              sleep 10
              th.kill
            end.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_set(:@reconnect_by, -> { sleep 1; false })
            allow(cli).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          it 'retries forever and does not raise error' do
            expect(hook).to receive(:call).and_call_original.once.at_least(:once)
            expect do
              th = cam.start_liveview_thread
              sleep 10
              th.kill
            end.to_not raise_error
          end
          after do
            cam.instance_variable_set(:@reconnect_by, method(:load_and_connect))
          end
        end
      end
    end
  end
end
