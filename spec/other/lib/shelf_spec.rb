require 'spec_helper'

module SonyCameraRemoteAPI
  describe Shelf do
    let(:sbj) { SonyCameraRemoteAPI::Shelf.new config_file }
    let(:config_file) { 'test.conf' }
    after :all do
      FileUtils.rm 'test.conf' if File.exists? 'test.conf'
    end

    describe '#initialize' do
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      it 'creates new config file' do
        sbj
        expect(File.exists? config_file).to eq true
      end
      it 'and config file is initialized' do
        config = YAML.load_file(config_file)
        expect(config['camera']).to eq []
        expect(config['default']).to eq nil
      end
    end

    describe '#add' do
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      it 'adds new camera config' do
        sbj.add 'ssid-1', 'pass-1', 'wlan-1'
        sbj.add 'ssid-2', 'pass-2', 'wlan-2'
        config = YAML.load_file(config_file)
        expect(config['camera'].map { |c| c['ssid'] }).to match_array %w(ssid-1 ssid-2)
      end
      context 'with overwrite: false' do
        it 'does not overwrite a duplicated config' do
          sbj.add 'ssid-2', 'pass-0', 'wlan-0'
          config = YAML.load_file(config_file)
          expect(config['camera'].find { |c| c['ssid'] == 'ssid-2' }).to match 'ssid' => 'ssid-2',
                                                                               'pass' => 'pass-2',
                                                                               'interface' => 'wlan-2'
        end
      end
      context 'with overwrite: true' do
        it 'overwrites a duplicated config' do
          sbj.add 'ssid-2', 'pass-0', 'wlan-0', overwrite: true
          config = YAML.load_file(config_file)
          expect(config['camera'].find { |c| c['ssid'] == 'ssid-2' }).to match 'ssid' => 'ssid-2',
                                                                               'pass' => 'pass-0',
                                                                               'interface' => 'wlan-0'
        end
      end
    end

    describe '#get' do
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      before :each do
        sbj.add 'ssid-1', 'pass-1', 'wlan-1'
        sbj.add 'ssid-2', 'pass-2', 'wlan-2'
      end
      it 'gets camera config' do
        expect(sbj.get('ssid-1')).to match 'ssid' => 'ssid-1', 'pass' => 'pass-1', 'interface' => 'wlan-1'
        expect(sbj.get('d-2')).to match 'ssid' => 'ssid-2', 'pass' => 'pass-2', 'interface' => 'wlan-2'
        expect(sbj.get('ssid-0')).to eq nil
      end
    end

    describe '#remove' do
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      before :each do
        sbj.add 'ssid-1', 'pass-1', 'wlan-1'
        sbj.add 'ssid-2', 'pass-2', 'wlan-2'
        sbj.add 'ssid-3', 'pass-3', 'wlan-3'
      end
      it 'removes camera config' do
        expect(sbj.get 'ssid-1').to_not eq nil
        expect(sbj.remove 'ssid-1').to eq true
        expect(sbj.get 'ssid-1').to eq nil

        expect(sbj.remove 'ssid').to eq false
      end
    end

    describe '#set_endpoints' do
      let(:endpoints) { {'camera' => 'http://aaa', 'avContent' => 'http://bbb'} }
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      before :each do
        sbj.add 'ssid-1', 'pass-1', 'wlan-1'
        sbj.add 'ssid-2', 'pass-2', 'wlan-2'
      end
      it 'sets endpoints' do
        sbj.set_endpoints endpoints, 'ssid-1'
        expect(sbj.get('ssid-1')['endpoints']).to match endpoints
        sbj.set_endpoints endpoints, 'ssid-0'
        expect(sbj.get('ssid-2')['endpoints']).to eq nil
      end
    end

    describe '#set_default/get_default' do
      before :all do
        FileUtils.rm 'test.conf' if File.exists? 'test.conf'
      end
      before :each do
        sbj.add 'ssid-1', 'pass-1', 'wlan-1'
        sbj.add 'ssid-2', 'pass-2', 'wlan-2'
        sbj.add 'ssid-3', 'pass-3', 'wlan-3'
      end
      it 'set default camera' do
        expect(sbj.get).to match 'ssid' => 'ssid-1', 'pass' => 'pass-1', 'interface' => 'wlan-1'
        sbj.select('ssid-2')
        expect(sbj.get).to match 'ssid' => 'ssid-2', 'pass' => 'pass-2', 'interface' => 'wlan-2'
        sbj.select('d-3')
        expect(sbj.get).to match 'ssid' => 'ssid-3', 'pass' => 'pass-3', 'interface' => 'wlan-3'

      end
    end
  end
end
