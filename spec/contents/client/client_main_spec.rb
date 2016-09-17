require 'spec_helper'
require 'date'


describe SonyCameraRemoteAPI::Client::Main, HDR_AZ1: true do
  let(:client) { @client }
  let(:image_dir) { 'images' }
  let(:valid_date) { '20160801' }
  let(:invalid_date) { '20151105' }
  let(:today) { Date.today.strftime('%Y%m%d') }


  describe "'contents' command" do
    context "without options" do
      it 'gets all contents' do
        out = capture(:stdout, true) { client.start(%W(contents)) }
        expect(out).to include("#{$NUM_ALL_3} contents found")
      end
    end
    context "with --type option" do
      it 'gets 213*3=639 still contents' do
        out = capture(:stdout, true) { client.start(%W(contents --type still)) }
        expect(out).to include("#{$NUM_STILL_3} contents found").and include('still')
        expect(out).not_to include('movie_mp4', 'movie_xavcs')
      end
      it 'gets 4*3=12 MP4 movie contents' do
        out = capture(:stdout, true) { client.start(%W(contents --type movie_mp4)) }
        expect(out).to include("#{$NUM_MP4_3} contents found").and include('movie_mp4')
        expect(out).not_to include('still', 'movie_xavcs')
      end
      it 'gets (3+2)*3=15 XAVCS movie contents' do
        out = capture(:stdout, true) { client.start(%W(contents --type movie_xavcs)) }
        expect(out).to include("#{$NUM_XAVCS_3} contents found").and include('movie_xavcs')
        expect(out).not_to include('still', 'movie_mp4')
      end
    end
    context "with --count option" do
      it 'shows contents by specified number' do
        out = capture(:stdout) { client.start(%W(contents --count 3)) }
        expect(out).to include("3 contents found")
        out = capture(:stdout) { client.start(%W(contents --count 101)) }
        expect(out).to include("101 contents found")
        out = capture(:stdout) { client.start(%W(contents --count 700)) }
        expect(out).to include("#{$NUM_ALL_3} contents found")
      end
    end
    context "with --type and --count option" do
      it 'shows still contents by the specified count' do
        out_1 = capture(:stdout, true) { client.start(%W(contents --type still --count 3)) }
        expect(out_1).to include('3 contents found', 'still')
        expect(out_1).not_to include('movie_mp4', 'movie_xavcs')
      end
      it 'shows MP4 contents by the specified count' do
        out_2 = capture(:stdout, true) { client.start(%W(contents --type movie_mp4 --count 3)) }
        expect(out_2).to include('3 contents found', 'movie_mp4')
        expect(out_2).not_to include('still', 'movie_xavcs')
      end
      it 'shows XAVCS contents by the specified count' do
        out_3 = capture(:stdout, true) { client.start(%W(contents --type movie_xavcs --count 3)) }
        expect(out_3).to include('3 contents found', 'movie_xavcs')
        expect(out_3).not_to include('still', 'movie_mp4')
      end
    end

    context "with --datelist" do
      it 'get a list of dates' do
        out = capture(:stdout, true) { client.start(%W(contents --datelist)) }
        expect(out).to include("3 date folders / #{$NUM_ALL_3} contents found", '20160801', '20160802', '20160803')
      end
    end

    context "with --date" do
      it 'gets the contents of the date' do
        out_1 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date})) }
        expect(out_1).to include("#{$NUM_ALL} contents found")
        out_2 = capture(:stdout, true) { client.start(%W(contents --date #{invalid_date})) }
        expect(out_2).to include('No contents!')
      end
    end
    context "with --date and --type option" do
      it 'shows contents of the type on the date' do
        out_1 = capture(:stdout) { client.start(%W(contents --date #{valid_date} --type movie_mp4)) }
        out_2 = capture(:stdout) { client.start(%W(contents --date #{invalid_date} --type movie_mp4)) }
        expect(out_1).to include("#{$NUM_MP4} contents found", 'movie_mp4')
        expect(out_2).to include('No contents!')
      end
    end
    context "with --date and --count option" do
      it 'shows specified number of contents of the date' do
        out = capture(:stdout) { client.start(%W(contents --date #{valid_date} --count 3)) }
        expect(out).to include("3 contents found")
      end
    end
    context "with --date, --type and --count option" do
      it 'shows specified number of contents of the date' do
        out_1 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type still --count 3)) }
        expect(out_1).to include('3 contents found', 'still')
        expect(out_1).not_to include('movie_mp4', 'movie_xavcs')
        out_2 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_mp4 --count 3)) }
        expect(out_2).to include('3 contents found', 'movie_mp4')
        expect(out_2).not_to include('still', 'movie_xavcs')
        out_3 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_xavcs --count 3)) }
        expect(out_3).to include('3 contents found', 'movie_xavcs')
        expect(out_3).not_to include('still', 'movie_mp4')
      end
    end
    context "with --date, --type, --count and --sort option" do
      it 'shows specified number of contents of the date' do
        out_1 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type still --count 3 --sort)) }
        expect(out_1).to include('3 contents found', 'still')
        expect(out_1).not_to include('movie_mp4', 'movie_xavcs')
        out_2 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_mp4 --count 3 --sort)) }
        expect(out_2).to include('3 contents found', 'movie_mp4')
        expect(out_2).not_to include('still', 'movie_xavcs')
        out_3 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_xavcs --count 3 --sort)) }
        expect(out_3).to include('3 contents found', 'movie_xavcs')
        expect(out_3).not_to include('still', 'movie_mp4')
      end
    end
    context "with --transfer option" do
      it 'shows and transfer the number of contents of the date' do
        out_1 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type still --count 3 --transfer)) }
        out_2 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_mp4 --count 3 --transfer)) }
        out_3 = capture(:stdout, true) { client.start(%W(contents --date #{valid_date} --type movie_xavcs --count 3 --transfer)) }
        expect(out_1).to include('3 contents found', 'still')
        expect(out_1).not_to include('movie_mp4', 'movie_xavcs')
        expect(out_2).to include('3 contents found', 'movie_mp4')
        expect(out_2).not_to include('still', 'movie_xavcs')
        expect(out_3).to include('3 contents found', 'movie_xavcs')
        expect(out_3).not_to include('still', 'movie_mp4')
      end
    end
    context "with --delete option" do
      it 'shows and delete the number of contents of the date' do
        allow_any_instance_of(HighLine).to receive(:ask).and_return("y")
        3.times.each do
          client.start(%W(still --no-transfer))
        end
        out = capture(:stdout, true) { client.start(%W(contents --date #{today} --type still --count 3 --delete)) }
        allow_any_instance_of(HighLine).to receive(:ask).and_call_original
        expect(out).to include('3 contents found', 'still')
        expect(out).not_to include('movie_mp4', 'movie_xavcs')

        out = capture(:stdout, true) { client.start(%W(contents --datelist)) }
        expect(out).to include("#{$NUM_ALL_3} contents found")
        # TODO: should we verify the rest of contents?
      end
    end
  end
end
