require 'spec_helper'


describe SonyCameraRemoteAPI do
  it 'has a version number' do
    expect(SonyCameraRemoteApi::VERSION).not_to be nil
  end
end

module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera do
    let(:cam) { @cam }

    ZOOM_ERROR_RANGE = 10
    describe '#zoom', DSC_RX100M4: true do
      context 'with absolute position' do
        context 'by invalid value' do
          it 'corrects value and zoom in till wide-end and zoom out till tele-end' do
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to receive(:zoom_until_end).exactly(2).times.and_call_original
            init, cur = cam.act_zoom absolute: -10
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(0).and eq(cur)
            init, cur = cam.act_zoom absolute: 110
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(100).and eq(cur)
          end
        end
        context 'valid value' do
          it 'zoom in till wide-end and zoom out till tele-end' do
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to receive(:zoom_until_end).exactly(2).times.and_call_original
            init, cur = cam.act_zoom absolute: 0
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(0).and eq(cur)
            init, cur = cam.act_zoom absolute: 100
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(100).and eq(cur)
          end
          it 'does not zoom if relative position is small' do
            init, cur = cam.act_zoom absolute: 50
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to_not receive(:actZoom)
            cam.act_zoom absolute: cur + SonyCameraRemoteAPI::Camera::SHORT_ZOOM_THRESHOLD/2
            cam.act_zoom absolute: cur - SonyCameraRemoteAPI::Camera::SHORT_ZOOM_THRESHOLD/2
          end
          it 'zoom in/out till absolute position' do
            5.times.each do
              pos = rand(101)
              init, cur = cam.act_zoom absolute: pos
              expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(cur)
              expect(cam.getEvent([false]).result[2]['zoomPosition']).to be_between(pos-ZOOM_ERROR_RANGE, pos+ZOOM_ERROR_RANGE)
            end
          end
        end
      end
      context 'with relative position' do
        context 'by invalid value' do
          it 'corrects value and zoom in till wide-end and zoom out till tele-end' do
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to receive(:zoom_until_end).exactly(2).times.and_call_original
            init, cur = cam.act_zoom relative: -200
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(0).and eq(cur)
            init, cur = cam.act_zoom relative: 200
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(100).and eq(cur)
          end
        end
        context 'valid value' do
          it 'zoom in till wide-end and zoom out till tele-end' do
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to receive(:zoom_until_end).exactly(2).times.and_call_original
            init, cur = cam.act_zoom relative: -100
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(0).and eq(cur)
            init, cur = cam.act_zoom relative: 100
            expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(100).and eq(cur)
          end
          it 'does not zoom if relative position is small' do
            init, cur = cam.act_zoom absolute: 50
            expect_any_instance_of(SonyCameraRemoteAPI::Camera).to_not receive(:actZoom)
            cam.act_zoom relative: SonyCameraRemoteAPI::Camera::SHORT_ZOOM_THRESHOLD/2
            cam.act_zoom relative: SonyCameraRemoteAPI::Camera::SHORT_ZOOM_THRESHOLD/2
          end
          it 'zoom in/out till relative position' do
            5.times.each do
              pos = rand(201)-100
              init, cur = cam.act_zoom relative: pos
              expect(cam.getEvent([false]).result[2]['zoomPosition']).to eq(cur)
              lower = [[init+pos-ZOOM_ERROR_RANGE, 100].min, 0].max
              upper = [[init+pos+ZOOM_ERROR_RANGE, 100].min, 0].max
              expect(cam.getEvent([false]).result[2]['zoomPosition']).to be_between lower, upper
            end
          end
        end
      end
    end


    describe '#cancel_focus', ILCE_QX1: true, DSC_RX100M4: true do
      context 'when focused somewhere' do
        before do
          focus_somewhere cam
        end
        it 'cancel focus' do
          expect(cam.focused?).to eq true
          cam.cancel_focus
          expect(cam.focused?).to eq false
        end
        after do
          cam.cancel_focus
        end
      end
    end

    describe '#2 type focuses transition', ILCE_QX1: true, DSC_RX100M4: true do
      def pos
        rand(101)
      end
      it 'transitions 2 type focuses without error' do
        expect(cam).to receive(:actHalfPressShutter).at_most(3).times.and_call_original
        expect(cam).to receive(:setTouchAFPosition).at_most(3).times.and_call_original
        expect(cam.act_focus).to eq(true).or eq(false)
        expect(cam.act_focus).to eq(true).or eq(false)
        expect(cam.act_touch_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_touch_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_focus).to eq(true).or eq(false)
      end
    end


    describe '#3 type focuses transition', ILCE_QX1: true do
      before  do
        set_mode_dial cam, 'still'
      end
      def pos
        rand(101)
      end
      it 'transitions 3 type focuses without error' do
        expect(cam).to receive(:actHalfPressShutter).at_most(3).times.and_call_original
        expect(cam).to receive(:setTouchAFPosition).at_most(2).times.and_call_original
        expect(cam).to receive(:actTrackingFocus).at_most(2).times.and_call_original
        expect(cam.act_focus).to eq(true).or eq(false)
        expect(cam.act_touch_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_tracking_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_focus).to eq(true).or eq(false)
        expect(cam.act_tracking_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_touch_focus(pos, pos)).to eq(true).or eq(false)
        expect(cam.act_focus).to eq(true).or eq(false)
      end
    end


    describe '#act_focus' do
      before do
        cam.cancel_focus
        set_mode_dial cam, 'still'
        cam.set_parameter :ContShootingMode, 'Single'
      end
      after do
        cam.cancel_focus
      end
      it 'can focus', DSC_RX100M4: true, ILCE_QX1: true do
        expect(cam.act_focus).to eq(true).or eq(false)
        cam.capture_still
        expect(cam.act_focus).to eq(true).or eq(false)
        expect(cam.act_focus).to eq(true).or eq(false)
      end
      it 'can be obtained its focus position from liveview frame information', ILCE_QX1: true do
        files = []
        frames = []
        cam.act_focus
        th = cam.start_liveview_thread do |img, info|
          files << "#{img.sequence_number}.jpg"
          frames += info.frames if info
        end
        loop do
          break if frames.size > 1
          sleep 1
          cam.act_focus
        end
        th.kill
        expect(frames.size).to be > 1
        expect(frames.map { |f| f.category }).to include(1).or include(5)
        expect(frames.find { |f| [1,5].include? f.category }.top_left.x).to be_between 0, 10000
        expect(frames.find { |f| [1,5].include? f.category }.top_left.y).to be_between 0, 10000
        puts frames.each { |f| puts "#{f.top_left}, #{f.bottom_right}"}
      end
    end


    describe '#act_touch_focus', DSC_RX100M4: true, ILCE_QX1: true do
      def pos
        rand(101)
      end
      def bad_pos
        (Set.new(-100..200) - Set.new(0..100)).to_a.sample
      end
      after do
        cam.cancel_focus
      end
      context 'with correct arguments' do
        it 'sets touch focus' do
          5.times.each do
            result = cam.act_touch_focus(pos, pos)
            expect(result).to eq(true).or eq(false)
            # expect(result).to eq('Touch').or eq('Wide').or eq(nil)
          end
        end
      end
      context 'with illegal arguments' do
        3.times.each do
          it 'sets touch focus with correcting' do
            result = cam.act_touch_focus(bad_pos, bad_pos)
            expect(result).to eq(true).or eq(false)
          end
        end
      end
    end


    describe '#tracking_focus', ILCE_QX1: true do
      def pos
        rand(101)
      end
      before do
        cam.act_tracking_focus pos, pos
      end
      after do
        cam.cancel_focus
      end
      it 'can be obtained its focus position from liveview frame information' do
        files = []
        frames = []
        th = cam.start_liveview_thread do |img, info|
          files << "#{img.sequence_number}.jpg"
          frames += info.frames if info
        end
        loop do
          break if frames.size > 1
          sleep 1
          cam.act_tracking_focus pos, pos
        end
        th.kill
        expect(frames.size).to be > 1
        expect(frames.map { |f| f.category }).to include(1).or include(5)
        expect(frames.find { |f| [1,5].include? f.category }.top_left.x).to be_between 0, 10000
        expect(frames.find { |f| [1,5].include? f.category }.top_left.y).to be_between 0, 10000
        puts frames.each { |f| puts "#{f.top_left}, #{f.bottom_right}"}
      end
    end
  end
end
