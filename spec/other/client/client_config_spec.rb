require 'spec_helper'

describe SonyCameraRemoteAPI::Client::Config do
  after :all do
    FileUtils.rm 'test.conf' if File.exists? 'test.conf'
  end
  describe "'config add' command" do
    let(:client) { SonyCameraRemoteAPI::Client::Main }
    let(:config) { 'test.conf' }
    before :all do
      FileUtils.rm 'test.conf' if File.exists? 'test.conf'
    end
    context 'when user answers YES to select it as default' do
      before do
        allow_any_instance_of(HighLine).to receive(:ask).and_return("y")
      end
      it 'add entry and select it as default' do
        output_0 = capture(:stdout) { client.start(%W(config add foo_0 bar_0 baz_0 --file #{config})) }
        output_1 = capture(:stdout) { client.start(%W(config add foo_1 bar_1 baz_1 --file #{config})) }
        output_11 = capture(:stdout) { client.start(%W(config add foo_11 bar_11 baz_11 --file #{config})) }
        output_2 = capture(:stdout) { client.start(%W(config add foo_2 bar_2 baz_2 --file #{config})) }
        expect(output_0).to include("=> 0: SSID      : foo_0")
        expect(output_1).to include("=> 1: SSID      : foo_1")
        expect(output_11).to include("=> 2: SSID      : foo_11")
        expect(output_2).to include("=> 3: SSID      : foo_2")
      end
      context 'when user answers YES to overwrite duplicated entry'  do
        it 'overwrite duplicated entry and select it as default' do
          output = capture(:stdout) { client.start(%W(config add foo_0 bar_9 baz_9 --file #{config})) }
          expect(output).to include("=> 0: SSID      : foo_0")
          expect(output).to include("      Password  : bar_9")
          expect(output).to include("      Interface : baz_9")
        end
      end
      context 'when user answers NO to overwrite duplicated entry'  do
        before do
          allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
        end
        it 'does not overwrite duplicated entry and default does not change' do
          output = capture(:stdout) { client.start(%W(config add foo_1 bar_9 baz_9 --file #{config})) }
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
        output = capture(:stdout) { client.start(%W(config add foo_3 bar_3 baz_3 --file #{config})) }
        expect(output).to include("=> 0: SSID      : foo_0")
        expect(output).to include("   4: SSID      : foo_3")
      end
    end
  end

  describe "'config remove' command" do
    let(:client) { SonyCameraRemoteAPI::Client::Main }
    let(:config) { "test.conf" }
    before :each do
      FileUtils.rm "test.conf" if File.exists? "test.conf"
      allow_any_instance_of(HighLine).to receive(:ask).and_return("y")
      capture(:stdout) { client.start(%W(config add foo_0 bar_0 baz_0 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_1 bar_1 baz_1 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_11 bar_11 baz_11 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_2 bar_2 baz_2 --file #{config})) }
      allow_any_instance_of(HighLine).to receive(:ask).and_call_original
    end
    context 'when user specify entry by ID' do
      context 'when removed entry is not selected as default' do
        it 'removes entry' do
          output = capture(:stdout) { client.start(%W(config remove --id 0 --file #{config})) }
          expect(output).not_to include("foo_0")
        end
      end
      context 'when removed entry is select as default' do
        it 'removes entry and warns default is none' do
          output = capture(:stdout) { client.start(%W(config remove --id 3 --file #{config})) }
          expect(output).not_to include("foo_2")
          expect(output).to include("Currently no camera is selected as default!")
        end
      end
      context 'when specfie ID is invalid' do
        it 'does not remove entry' do
          output = capture(:stdout) { client.start(%W(config remove --id 4 --file #{config})) }
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
            output = capture(:stdout) { client.start(%W(config remove --ssid foo_1 --file #{config})) }
            expect(output).not_to match("foo_1\s+")
            expect(output).to match("foo_11\s+")
          end
        end
        context 'when removed entry is select as default' do
          it 'removes entry and warns default is none' do
            output = capture(:stdout) { client.start(%W(config remove --ssid foo_2 --file #{config})) }
            expect(output).to include("Currently no camera is selected as default!")
          end
        end
      end
      context 'when SSID partially matches but identical' do
        it 'removes entry' do
          output = capture(:stdout) { client.start(%W(config remove --ssid o_11 --file #{config})) }
          expect(output).not_to include("foo_11")
        end
      end
      context 'when SSID partially matches but ambigous' do
        it 'does not remove entry' do
          output = capture(:stdout) { client.start(%W(config remove --ssid foo --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("=> 3: SSID      : foo_2")
        end
      end
      context 'when SSID does not match' do
        it 'does not remove entry' do
          output = capture(:stdout) { client.start(%W(config remove --ssid bar --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("=> 3: SSID      : foo_2")
        end
      end
    end
  end

  describe "'config select' command" do
    let(:client) { SonyCameraRemoteAPI::Client::Main }
    let(:config) { 'test.conf' }
    before :each do
      FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      allow_any_instance_of(HighLine).to receive(:ask).and_return("n")
      capture(:stdout) { client.start(%W(config add foo_0 bar_0 baz_0 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_1 bar_1 baz_1 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_11 bar_11 baz_11 --file #{config})) }
      capture(:stdout) { client.start(%W(config add foo_2 bar_2 baz_2 --file #{config})) }
      allow_any_instance_of(HighLine).to receive(:ask).and_call_original
    end
    context 'when ID is used' do
      it 'selects camera' do
        output = capture(:stdout) { client.start(%W(config use --id 0 --file #{config})) }
        expect(output).to include("=> 0: SSID      : foo_0")
        expect(output).to include("   1: SSID      : foo_1")
        expect(output).to include("   2: SSID      : foo_11")
        expect(output).to include("   3: SSID      : foo_2")
        output = capture(:stdout) { client.start(%W(config use --id 2 --file #{config})) }
        expect(output).to include("   0: SSID      : foo_0")
        expect(output).to include("   1: SSID      : foo_1")
        expect(output).to include("=> 2: SSID      : foo_11")
        expect(output).to include("   3: SSID      : foo_2")
      end
      context 'when ID is invalid' do
        it 'does not select camera' do
          output = capture(:stdout) { client.start(%W(config use --id 4 --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
      end
    end
    context 'when SSID is used' do
      context 'when SSID matches compelely' do
        it 'selects camera' do
          output = capture(:stdout) { client.start(%W(config use --ssid foo_1 --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("=> 1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
      end
      context 'when SSID partially matches but identical' do
        it 'selects entry' do
          output = capture(:stdout) { client.start(%W(config use --ssid o_11 --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("=> 2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
      end
      context 'when SSID partially matches but ambigous' do
        it 'does not select entry' do
          output = capture(:stdout) { client.start(%W(config use --ssid foo --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
      end
      context 'when SSID does not match' do
        it 'does not select entry' do
          output = capture(:stdout) { client.start(%W(config use --ssid bar --file #{config})) }
          expect(output).to include("   0: SSID      : foo_0")
          expect(output).to include("   1: SSID      : foo_1")
          expect(output).to include("   2: SSID      : foo_11")
          expect(output).to include("   3: SSID      : foo_2")
        end
      end
    end
  end

end
