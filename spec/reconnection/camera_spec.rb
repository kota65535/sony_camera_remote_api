require 'spec_helper'


module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera, HDR_AZ1: true do
    let(:cam) { @cam_rcn }
    let(:http)  { cam.instance_variable_get(:@http) }
    let(:recon) { cam.instance_variable_get(:@retrying).instance_variable_get(:@reconnect_by) }
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
          # Stubs to fail API only once
          before do
            allow(http).to receive(:get_content) do
              allow(http).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and execute API' do
            expect(recon).to receive(:call).and_call_original.once
            expect { cam.capture_still }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, -> { false })
            allow(http).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          after do
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          it 'gives up to execute and raise error' do
            expect(recon).to receive(:call).and_call_original.
                exactly(SonyCameraRemoteAPI::Retrying::DEFAULT_RECONNECTION_LIMIT).times
            expect { cam.capture_still }.to raise_error HTTPClient::ReceiveTimeoutError
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
          # Stubs to fail API only once
          before do
            allow(http).to receive(:get_content) do
              allow(http).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and execute API' do
            expect(recon).to receive(:call).and_call_original.once
            expect { cam.transfer_contents(cam.get_content_list(type: 'still', count: 1)) }.to_not raise_error
          end
        end
        context 'permanently' do
          # Stubs permanently to fail API execution and reconnection
          before do
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, -> { false })
            allow(http).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          after do
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          it 'gives up to execute and raise error' do
            expect(recon).to receive(:call).and_call_original.
                exactly(SonyCameraRemoteAPI::Retrying::DEFAULT_RECONNECTION_LIMIT).times
            expect { cam.transfer_contents(cam.get_content_list(type: 'still', count: 1)) }.to raise_error HTTPClient::ReceiveTimeoutError
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
          # Stubs to fail API only once
          before do
            allow(http).to receive(:get_content) do
              allow(http).to receive(:get_content).and_call_original
              raise HTTPClient::ReceiveTimeoutError
            end
          end
          it 'reconnects and execute API' do
            expect(recon).to receive(:call).and_call_original.at_least(:once)
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
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, -> { false })
            allow(http).to receive(:get_content).and_raise(HTTPClient::ReceiveTimeoutError)
          end
          after do
            cam.instance_variable_get(:@retrying).instance_variable_set(:@reconnect_by, @shelf.method(:connect))
          end
          it 'retries forever and does not raise error' do
            expect(recon).to receive(:call).and_call_original.once.at_least(:once)
            expect do
              th = cam.start_liveview_thread
              sleep 10
              th.kill
            end.to_not raise_error
          end
        end
      end
    end
  end
end
