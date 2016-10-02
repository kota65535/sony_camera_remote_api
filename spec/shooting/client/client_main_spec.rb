require 'spec_helper'
require 'date'


describe SonyCameraRemoteAPI::Client::Main do
  let(:cam) { @cam }
  let(:client) { @client }
  let(:image_dir) { 'images' }
  before :each do
    FileUtils.rm_r image_dir if Dir.exists? image_dir
    FileUtils.mkdir image_dir
  end

  describe '--settings option' do
    describe 'get_parameter_and_show' do
      before do
        set_mode_dial cam, 'still'
      end
      context 'with normal parameter', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
        it 'shows supported/available/current values of the parameter' do
          begin
            output = capture(:stdout, true) { client.start(%W(still --setting --self 0 --postview 2M)) }
            puts output
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          expect(output).to include('Self Timer:')
          expect(output).to include('   * 10')
          expect(output).to include('   * 2')
          expect(output).to include('  => 0')
          expect(output).to include('Postview Image Size:')
          expect(output).to include('   * Original')
          expect(output).to include('  => 2M')
        end
      end
      context 'with WhiteBalance parameter', FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
        it 'shows supported/available/current mode' do
          begin
            output = capture(:stdout, true) { client.start(%W(still --setting --wb Auto\ WB)) }
            puts output
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          expect(output).to include('White Balance:')
          expect(output).to include('  => Auto WB')
          expect(output).to   match('Color Temperature  \(\d+-\d+K, step=\d+\)')
        end
        it 'shows color temperature when Color Temperature mode is selected' do
          begin
            output = capture(:stdout, true) { client.start(%W(still --setting --wb Color\ Temperature --temp 5000)) }
            puts output
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          expect(output).to include('White Balance:')
          expect(output).to include('   * Auto WB')
          expect(output).to   match('  => Color Temperature, \d+K  \(\d+-\d+K, step=\d+\)')
        end
      end
    end
  end


  describe 'still command', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
    before do
      set_mode_dial cam, 'still'
    end
    it 'captures single still image and transfer postview' do
      begin
        output = capture(:stdout, true) { client.start(%W(still --dir #{image_dir} --postview Original)) }
      rescue SystemExit => e
        expect(e.status).to eq 0
      end
      expect(output).to match(/Transferred DSC\d+\.JPG/)
      expect(Dir.entries(image_dir)).to include(output.match(/Transferred (DSC\d+\.JPG)/)[1])
    end

    it 'captures single still image and does not transfer postview' do
      begin
        output = capture(:stdout, true) { client.start(%W(still --dir #{image_dir} --no-transfer --postview 2M)) }
      rescue SystemExit => e
        expect(e.status).to eq 0
      end
      expect(output).not_to match(/Transferred DSC\d+\.JPG/)
    end

    context 'with interval option' do
      context 'and the interval value is long enough' do
        context 'with time option' do
          it 'capture stills by the interval until the time elapses' do
            begin
              output = capture(:stdout, true) { client.start(%W(still --dir #{image_dir} --interval 5 --time 10)) }
            rescue SystemExit => e
              expect(e.status).to eq 0
            end
            matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
            expect(Dir.entries(image_dir)).to include(*matched)
          end
        end
        context 'without time option' do
          it 'capture stills by the interval until SIGINT sent' do
            output = capture_process(6) { client.start(%W(still --dir #{image_dir} --interval 5)) }
            matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
            expect(matched.size).to be >= 1
            expect(Dir.entries(image_dir)).to include(*matched)
          end
        end
      end
      context 'and the interval value is too short' do
        it 'capture stills at the best-effort interval' do
          begin
            output = capture(:stdout, true) { client.start(%W(still --dir #{image_dir} --interval 1 --time 10)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
          expect(matched.size).to be >= 1
          expect(Dir.entries(image_dir)).to include(*matched)
        end
      end
    end
    context 'with --no-transfer option' do
      it 'does not transfer the catured still' do
        begin
          output = capture(:stdout, true) { client.start(%W(still --dir #{image_dir} --no-transfer)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 0
      end
    end

    context 'with --setting option' do
      it 'shows current settings' do
        begin
          output = capture(:stdout, true) { client.start(%W(still --setting --postview 2M)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        expect(output).to include('Postview Image Size:')
        expect(output).to include('  => 2M')
      end
    end
  end

  describe 'rapid command' do
    before do
      set_mode_dial cam, 'still'
    end
    context 'for ActionCam', HDR_AZ1: true, FDR_X1000V: true do
      context 'in burst mode' do
        it 'captures images by burst mode and transfer postviews' do
          begin
            output = capture(:stdout, true) { client.start(%W(rapid --dir #{image_dir} --mode Burst --speed 10fps\ 1sec --transfer)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
          expect(matched.size).to eq 10
          expect(Dir.entries(image_dir)).to include(*matched)
        end
      end
      context 'in motion-shot mode' do
        it 'captures images by motion-shot mode and transfer postview' do
          begin
            output = capture(:stdout, true) { client.start(%W(rapid --dir #{image_dir} --mode MotionShot --speed 10fps\ 1sec --transfer)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
          expect(matched.size).to eq 1
          expect(Dir.entries(image_dir)).to include(*matched)
        end
      end
      context 'without --transfer option' do
        it 'does not transfer recorded stills' do
          begin
            output = capture(:stdout, true) { client.start(%W(rapid --dir #{image_dir} --mode Burst)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
          expect(matched.size).to eq 0
        end
      end
    end

    context 'in cont-shooting mode', DSC_RX100M4: true, ILCE_QX1: true do
      before do
        set_mode_dial cam, 'still'
      end
      context 'with time option' do
        it 'captures stills continuously until the time elapses' do
          begin
            output = capture(:stdout, true) { client.start(%W(rapid --dir #{image_dir} --mode Continuous --time 3 --transfer)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
          expect(matched.size).to be >= 1
          expect(Dir.entries(image_dir)).to include(*matched)
        end
      end
      context 'without time option' do
        it 'captures stills continuously until SIGINT sent' do
          output = capture_process(6) { client.start(%W(rapid --dir #{image_dir} --mode Continuous --transfer)) }
          matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
          expect(matched.size).to be >= 1
          expect(Dir.entries(image_dir)).to include(*matched)
        end
      end
      context 'without --transfer option' do
        it 'does not transfer recorded stills' do
          begin
            output = capture(:stdout, true) { client.start(%W(rapid --dir #{image_dir} --mode Continuous --time 3)) }
          rescue SystemExit => e
            expect(e.status).to eq 0
          end
          matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
          expect(matched.size).to eq 0
        end
      end
    end

    context 'with --setting option' do
      it 'shows current settings' do
        begin
          output = capture(:stdout, true) { client.start(%W(rapid --setting)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        expect(output).to include("Cont Shooting Mode:")
        expect(output).to include("  => MotionShot")
        expect(output).to include("Cont Shooting Speed:")
        expect(output).to include("  => 5fps 2sec")
      end
    end
  end

  describe 'intstill command', HDR_AZ1: true, FDR_X1000V: true do
    context 'with time option' do
      it 'capture stills by the interval until the time elapses' do
        begin
          output = capture(:stdout, true) { client.start(%W(intstill --dir #{image_dir} --interval 2 --time 10 --transfer)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
        expect(matched.size).to be >= 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without time option' do
      it 'captures stills by the interval until SIGINT sent' do
        output = capture_process(6) { client.start(%W(intstill --dir #{image_dir} --interval 2 --transfer)) }
        matched = output.scan(/Transferred (DSC\d+\.JPG)/).map { |e| e[0] }
        expect(matched.size).to be >= 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without --transfer option' do
      it 'does not transfer recorded stills' do
        begin
          output = capture(:stdout, true) { client.start(%W(intstill --dir #{image_dir} --interval 5 --time 10)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 0
      end
    end

    context 'with --setting option' do
      it 'shows current settings' do
        begin
          output = capture(:stdout, true) { client.start(%W(intstill --setting --interval 2)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        expect(output).to include("Interval Time:")
        expect(output).to include("  => 2")
      end
    end
  end

  describe 'movie command', HDR_AZ1: true, FDR_X1000V: true, ILCE_QX1: true do
    before do
      set_mode_dial cam, 'movie'
    end
    context 'with time option' do
      it 'records movie until the time elapses' do
        begin
          output = capture(:stdout, true) { client.start(%W(movie --dir #{image_dir} --format MP4 --time 5 --transfer)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without time option' do
      it 'records movie until SIGINT sent' do
        output = capture_process(6) { client.start(%W(movie --dir #{image_dir} --format MP4 --transfer)) }
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without --transfer option' do
      it 'does not transfer recorded movie' do
        begin
          output = capture(:stdout, true) { client.start(%W(movie --dir #{image_dir} --format MP4 --time 5)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 0
      end
    end

    # context 'with --setting option' do
    #   it 'shows current settings' do
    #     begin
    #       output = capture(:stdout, true) { client.start(%W(movie --setting --format MP4)) }
    #     rescue SystemExit => e
    #       expect(e.status).to eq 0
    #     end
    #     expect(output).to include("Movie File Format:")
    #     expect(output).to include("  => MP4")
    #   end
    # end
  end

  describe 'looprec command', FDR_X1000V: true do
    context 'with time option' do
      it 'records movie until the time elapses' do
        begin
          output = capture(:stdout, true) { client.start(%W(looprec --dir #{image_dir} --format MP4 --time 0.1 --transfer)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without time option' do
      it 'records movie until SIGINT sent' do
        output = capture_process(6) { client.start(%W(looprec --dir #{image_dir} --format MP4 --transfer)) }
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'without --transfer option' do
      it 'does not transfer recorded movie' do
        begin
          output = capture(:stdout, true) { client.start(%W(looprec --dir #{image_dir} --format MP4 --time 0.1)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Transferred ((C|MAH|MAF)\d+\.MP4)/).map { |e| e[0] }
        expect(matched.size).to eq 0
      end
    end
    context 'with --setting option' do
      it 'shows current settings' do
        begin
          output = capture(:stdout, true) { client.start(%W(looprec --setting --format MP4)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        expect(output).to include("Movie File Format:")
        expect(output).to include("  => MP4")
      end
    end
  end


  describe 'liveview command' do
    context 'with time option', HDR_AZ1: true, FDR_X1000V: true, DSC_RX100M4: true, ILCE_QX1: true do
      it 'starts streaming and finishes after 5 seconds' do
        begin
          output = capture(:stdout, true) { client.start(%W(liveview --dir #{image_dir} --time 5)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        matched = output.scan(/Wrote: (\d+\.jpg)/).map { |e| e[0] }
        expect(matched.size).to be > 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    # TODO: Cannot capture output of the thread of subprocess???
    context 'with size option', DSC_RX100M4: true do
      it 'starts streaming with specified liveview size' do
        output = capture_process(5) { client.start(%W(liveview --dir #{image_dir} --size L)) }
        matched = output.scan(/Wrote: (\d+\.jpg)/).map { |e| e[0] }
        expect(matched.size).to be > 1
        expect(Dir.entries(image_dir)).to include(*matched)
      end
    end
    context 'with --setting option', DSC_RX100M4: true do
      it 'shows current settings' do
        begin
          output = capture(:stdout, true) { client.start(%W(liveview --setting)) }
        rescue SystemExit => e
          expect(e.status).to eq 0
        end
        expect(output).to include("Liveview Size:")
        expect(output).to include("  => L")
      end
    end
  end
end
