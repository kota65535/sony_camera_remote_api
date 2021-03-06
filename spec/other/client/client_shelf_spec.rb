require 'spec_helper'

module SonyCameraRemoteAPI
  describe Client::ShelfCmd do
    let(:client) { SonyCameraRemoteAPI::Client::Main }
    let(:config) { 'test.conf' }
    after :all do
      FileUtils.rm 'test.conf' if File.exists? 'test.conf'
    end

    describe "'shelf add' command" do
      before do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      context 'when user answers YES to select it as default' do
        before do
          allow_any_instance_of(HighLine).to receive(:ask).and_return("y")
        end
        it 'add entry and select it as default' do
          output_0 = capture(:stdout) { client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config})) }
          output_1 = capture(:stdout) { client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config})) }
          output_11 = capture(:stdout) { client.start(%W(shelf add foo_11 bar_11 baz_11 --file #{config})) }
          output_2 = capture(:stdout) { client.start(%W(shelf add foo_2 bar_2 baz_2 --file #{config})) }
          expect(output_0).to include("=> 0: SSID      : foo_0")
          expect(output_1).to include("=> 1: SSID      : foo_1")
          expect(output_11).to include("=> 2: SSID      : foo_11")
          expect(output_2).to include("=> 3: SSID      : foo_2")
        end
        context 'when user answers YES to overwrite duplicated entry' do
          it 'overwrite duplicated entry and select it as default' do
            client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config}))
            output = capture(:stdout) { client.start(%W(shelf add foo_0 bar_9 baz_9 --file #{config})) }
            expect(output).to include("=> 0: SSID      : foo_0")
            expect(output).to include("      Password  : bar_9")
            expect(output).to include("      Interface : baz_9")
          end
        end
        context 'when user answers NO to overwrite duplicated entry' do
          before do
            allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
          end
          it 'does not overwrite duplicated entry and default does not change' do
            client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config}))
            client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config}))
            output = capture(:stdout) { client.start(%W(shelf add foo_1 bar_9 baz_9 --file #{config})) }
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("      Password  : bar_1")
            expect(output).to include("      Interface : baz_1")
            expect(output).to include("=> 0: SSID      : foo_0")
          end
        end
      end
      context 'when user answers NO to select it as default' do
        before do
          allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
        end
        it 'add entry but default does not change' do
          client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config}))
          output = capture(:stdout) { client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config})) }
          expect(output).to include("=> 0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
        end
      end
    end

    describe "'shelf remove' command" do
      before do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
        allow_any_instance_of(HighLine).to receive(:ask).and_return("y")
        capture(:stdout) { client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_11 bar_11 baz_11 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_2 bar_2 baz_2 --file #{config})) }
        allow_any_instance_of(HighLine).to receive(:ask).and_call_original
      end
      context 'when user specify entry by ID' do
        context 'when removed entry is not selected as default' do
          it 'removes entry' do
            output = capture(:stdout) { client.start(%W(shelf remove 0 --file #{config})) }
            expect(output).not_to include("foo_0")
          end
        end
        context 'when removed entry is select as default' do
          it 'removes entry and warns default is none' do
            output = capture(:stdout) { client.start(%W(shelf remove 3 --file #{config})) }
            expect(output).not_to include("foo_2")
            expect(output).to include("Default camera is not selected yet!")
          end
        end
        context 'when specfie ID is invalid' do
          it 'does not remove entry' do
            output = capture(:stdout) { client.start(%W(shelf remove 4 --file #{config})) }
            expect(output).to include("   0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("=> 3: SSID      : foo_2")
          end
        end
      end
      context 'when user specify entry by SSID' do
        context 'when SSID matches compelely' do
          context 'when removed entry is not selected as default' do
            it 'removes entry' do
              output = capture(:stdout) { client.start(%W(shelf remove foo_1 --file #{config})) }
              expect(output).not_to match("foo_1\s+")
              expect(output).to match("foo_11\s+")
            end
          end
          context 'when removed entry is select as default' do
            it 'removes entry and warns default is none' do
              output = capture(:stdout) { client.start(%W(shelf remove foo_2 --file #{config})) }
              expect(output).to include("Default camera is not selected yet!")
            end
          end
        end
        context 'when SSID partially matches but identical' do
          it 'removes entry' do
            output = capture(:stdout) { client.start(%W(shelf remove o_11 --file #{config})) }
            expect(output).not_to include("foo_11")
          end
        end
        context 'when SSID partially matches but ambigous' do
          it 'does not remove entry' do
            output = capture(:stdout) { client.start(%W(shelf remove foo --file #{config})) }
            expect(output).to include("   0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("=> 3: SSID      : foo_2")
          end
        end
        context 'when SSID does not match' do
          it 'does not remove entry' do
            output = capture(:stdout) { client.start(%W(shelf remove bar --file #{config})) }
            expect(output).to include("   0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("=> 3: SSID      : foo_2")
          end
        end
      end
    end

    describe "'shelf select' command" do
      before :each do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
        allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
        capture(:stdout) { client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_11 bar_11 baz_11 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_2 bar_2 baz_2 --file #{config})) }
        allow_any_instance_of(HighLine).to receive(:ask).and_call_original
      end
      it 'already selects first added camera' do
        output = capture(:stdout) { client.start(%W(shelf list --file #{config})) }
        expect(output).to include("=> 0: SSID      : foo_0")
      end
      context 'when ID is selectd' do
        it 'selects camera' do
          output = capture(:stdout) { client.start(%W(shelf select 0 --file #{config})) }
          expect(output).to include("=> 0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
          output = capture(:stdout) { client.start(%W(shelf select 2 --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("=> 2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
        context 'when ID is invalid' do
          it 'does not select camera' do
            output = capture(:stdout) { client.start(%W(shelf select 4 --file #{config})) }
            expect(output).to include("=> 0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("   3: SSID      : foo_2")
          end
        end
      end
      context 'when SSID is selectd' do
        context 'when SSID matches compelely' do
          it 'selects camera' do
            output = capture(:stdout) { client.start(%W(shelf select foo_1 --file #{config})) }
            expect(output).to include("   0: SSID      : foo_0")
            expect(output).to include("=> 1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("   3: SSID      : foo_2")
          end
        end
        context 'when SSID partially matches but identical' do
          it 'selects entry' do
            output = capture(:stdout) { client.start(%W(shelf select o_11 --file #{config})) }
            expect(output).to include("   0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("=> 2: SSID      : foo_11")
            expect(output).to include("   3: SSID      : foo_2")
          end
        end
        context 'when SSID partially matches but ambigous' do
          it 'does not select entry' do
            output = capture(:stdout) { client.start(%W(shelf select foo --file #{config})) }
            expect(output).to include("=> 0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("   3: SSID      : foo_2")
          end
        end
        context 'when SSID does not match' do
          it 'does not select entry' do
            output = capture(:stdout) { client.start(%W(shelf select bar --file #{config})) }
            expect(output).to include("=> 0: SSID      : foo_0")
            expect(output).to include("   1: SSID      : foo_1")
            expect(output).to include("   2: SSID      : foo_11")
            expect(output).to include("   3: SSID      : foo_2")
          end
        end
      end
    end

    describe "'shelf interface' command" do
      before :each do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
        allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
        capture(:stdout) { client.start(%W(shelf add foo_0 bar_0 baz_0 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_1 bar_1 baz_1 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_11 bar_11 baz_11 --file #{config})) }
        capture(:stdout) { client.start(%W(shelf add foo_2 bar_2 baz_2 --file #{config})) }
        allow_any_instance_of(HighLine).to receive(:ask).and_call_original
      end
      it 'sets interface by which the camera is connected' do
        output = capture(:stdout) { client.start(%W(shelf interface baz_0 foo_1 --file #{config})) }
        output_ary = output.split "\n"
        expect(output_ary[0]).to include("=> 0: SSID      : foo_0")
        expect(output_ary[2]).to include("      Interface : baz_0")
        expect(output_ary[3]).to include("   1: SSID      : foo_1")
        expect(output_ary[4]).to include("      Password  : bar_1")
        expect(output_ary[5]).to include("      Interface : baz_0")
        output = capture(:stdout) { client.start(%W(shelf interface baz_0 2 --file #{config})) }
        output_ary = output.split "\n"
        expect(output_ary[6]).to include("   2: SSID      : foo_11")
        expect(output_ary[8]).to include("      Interface : baz_0")
        output = capture(:stdout) { client.start(%W(shelf interface baz_9 --file #{config})) }
        output_ary = output.split "\n"
        expect(output_ary[0]).to include("=> 0: SSID      : foo_0")
        expect(output_ary[2]).to include("      Interface : baz_9")
      end

      it 'does not set interface' do
        output = capture(:stdout) { client.start(%W(shelf list --file #{config})) }
        client.start(%W(shelf interface baz_0 hogehoge --file #{config}))
        output2 = capture(:stdout) { client.start(%W(shelf list --file #{config})) }
        expect(output).to eq output2
      end
    end
  end
end
