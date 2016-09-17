require 'spec_helper'


module SonyCameraRemoteAPI
  describe SonyCameraRemoteAPI::Camera, HDR_AZ1: true, ILCE_QX1: true do
    let(:cam) { @cam }
    let(:client) { @client }
    let(:today) { Date.today.strftime('%Y%m%d') }
    before do
      cam.change_function_to_transfer
    end

    describe '#change_function_to_transfer' do
      it "change camera function to 'Contents Transfer' and wait it completes." do
        cam.change_function_to_transfer
        result = cam.getEvent([false])['result']
        expect(result[12]['currentCameraFunction']).to eq('Contents Transfer')

        cam.change_function_to_shoot 'still', 'Single'
        result = cam.getEvent([false])['result']
        expect(result[12]['currentCameraFunction']).to eq('Remote Shooting')
        expect(result[21]['currentShootMode']).to eq('still')
        expect(result[38]['contShootingMode']).to eq('Single')
      end
    end

    # Gets a list of pairs of a date and a number of contents of the date.
    describe '#get_date_list' do
      context 'with no option' do
        it 'get all pairs of date and the number of contents' do
          dates_counts = cam.get_date_list
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.map { |d, c| d['title'] }).to all(match(/2016080?/))
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_ALL))
        end
      end
      context 'with type option' do
        it 'get all dates having movie_mp4 contents and its number' do
          dates_counts = cam.get_date_list type: 'movie_mp4'
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.map { |d, c| d['title'] }).to all(match(/2016080?/))
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_MP4))
        end
      end
      context 'with type option (multiple)' do
        it 'get all dates having movie_mp4 or movie_xavcs contents and its total number' do
          dates_counts = cam.get_date_list type: %w(movie_mp4 movie_xavcs)
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.map { |d, c| d['title'] }).to all(match(/2016080?/))
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_MP4+$NUM_XAVCS))
        end
      end
      context 'with date_count option' do
        it 'get dates by date_count' do
          dates_counts = cam.get_date_list date_count: 3
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.map { |d, c| d['title'] }).to all(match(/2016080?/))
          expect(dates_counts.size).to eq(3)
        end
      end
      context 'with content_count option' do
        it 'get dates so that the number of contents reaches content_count' do
          dates_counts = cam.get_date_list content_count: $NUM_ALL+1
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.map { |d, c| d['title'] }).to all(match(/2016080?/))
          expect(dates_counts.size).to eq(2)
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_ALL))
        end
      end
      context 'with type and date_count option' do
        it 'get dates having moive_mp4 by date_count' do
          dates_counts = cam.get_date_list type: 'movie_mp4', date_count: 3
          expect(dates_counts.size).to eq(3)
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_MP4))
        end
      end
      context 'with type and content_count option' do
        it 'get dates having movie_mp4 so that the number of contents reaches content_count' do
          dates_counts = cam.get_date_list type: 'movie_mp4', content_count: $NUM_MP4*2+1
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          expect(dates_counts.size).to eq(3)
          expect(dates_counts.map { |d, c| c }).to all(eq($NUM_MP4))
          # expect(dates_counts.transpose[1].inject(:+)).to eq(13)
        end
      end
      context 'with sort option' do
        it 'get all dates and the number of contents in ascending order' do
          dates_counts = cam.get_date_list(sort: 'ascending')
          dates_counts.each do |date, count|
            puts "#{date['title']}\t#{count}"
          end
          # TODO: write expectation
        end
      end
    end

    describe '#get_content_list' do

      context 'without date option' do
        it 'gets all mp4 contents in ascending order' do
          contents = cam.get_content_list(type: 'movie_mp4', sort: 'ascending')
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(contents.map { |c| c['contentKind'] }).to all(eq('movie_mp4'))
          expect(contents[0]['createdTime']).to match(/2016-08-01.*/)
          expect(contents[-1]['createdTime']).to match(/2016-08-03.*/)
          expect(contents.size).to eq($NUM_MP4*3)
        end
        it 'gets newest 1 still contents ' do
          contents = cam.get_content_list(type: 'still', count: 1)
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(contents.map { |c| c['contentKind'] }).to all(eq('still'))
          expect(contents.map { |c| c['createdTime'] }).to all(match(/2016-08-03.*/))
          expect(contents.size).to eq(1)
        end
        it 'gets newest 10 still contents' do
          contents = cam.get_content_list(type: 'still', count: 10)
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(contents.map { |c| c['contentKind'] }).to all(eq('still'))
          expect(contents.map { |c| c['createdTime'] }).to all(match(/2016-08-03.*/))
          expect(contents.size).to eq(10)
        end
        it 'gets 99 newest contents' do
          contents = cam.get_content_list(count: 99)
          expect(contents.size).to eq(99)
        end
        it 'gets 100 newest contents' do
          contents = cam.get_content_list(count: 100)
          expect(contents.size).to eq(100)
        end
        it 'gets 101 newest contents' do
          contents = cam.get_content_list(count: 101)
          expect(contents.size).to eq(101)
        end
        it 'gets 199 newest contents' do
          contents = cam.get_content_list(count: 199)
          expect(contents.size).to eq(199)
        end
        it 'gets 200 newest contents' do
          contents = cam.get_content_list(count: 200)
          expect(contents.size).to eq(200)
        end
        it 'gets 201 newest contents' do
          contents = cam.get_content_list(count: 201)
          expect(contents.size).to eq(201)
        end
      end
      context 'with date option' do
        it 'gets all contents at the date in ascening order' do
          contents = cam.get_content_list(date: '20160802', sort: 'ascending')
          # contents.each do |c|
          #   puts c['content']['original'][0]['url']
          # end
          created_times = contents.map { |c| Time.iso8601(c['createdTime']) }
          expect(contents.size).to eq($NUM_ALL)
          expect(created_times[0] - created_times[-1]).to be < 0
          expect(contents.map { |c| c['createdTime'] }).to all(match(/2016-08-02.*/))

        end
        it 'gets 10 contents at the date in descending order' do
          contents = cam.get_content_list(date: '20160801', count: 10)
          # contents.each do |c|
          #   puts c['content']['original'][0]['url']
          # end
          created_times = contents.map { |c| Time.iso8601(c['createdTime']) }
          expect(contents.size).to eq(10)
          expect(created_times[0] - created_times[-1]).to be > 0
          expect(contents.map { |c| c['createdTime'] }).to all(match(/2016-08-01.*/))
        end
        it 'gets all mp4 contents at the date in ascending order' do
          contents = cam.get_content_list(type: 'movie_xavcs', date: '20160801', sort: 'ascending')
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(contents.size).to eq($NUM_XAVCS)
          expect(contents.map { |c| c['createdTime'] }).to all(match(/2016-08-01.*/))
        end
        it 'gets all contents at the date' do
          contents = cam.get_content_list(type: 'still', date: '20000101', sort: 'ascending')
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(contents.size).to eq(0)
        end
      end
    end

    describe '#transfer_contents' do
      let(:dir) { 'images' }
      let(:filenames) { (1..5).map { |n| "test_#{n}.JPG" } }
      let(:contents) { cam.get_content_list type: 'still', count: 5 }
      before :each do
        FileUtils.rm_r 'images' if Dir.exists? 'images'
      end
      after :each do
        FileUtils.rm_r 'images' if Dir.exists? 'images'
      end
      context 'without filename argument' do
        it 'gets 5 still contents by original filenames' do
          cam.transfer_contents contents, dir: dir, size: 'thumbnail'
          expect(Dir.entries(dir).count { |e| e.match(/DSC\d+\.JPG/) }).to eq(5)
        end
      end
      context 'with filename array whose size is equal to contents' do
        it 'gets 5 still contents by given filenames' do
          cam.transfer_contents contents, filenames, dir: dir, size: 'small'
          contents.each do |c|
            puts c['content']['original'][0]['url']
          end
          expect(Dir.entries(dir).count { |e| e.match(/test_\d.JPG/) }).to eq(5)
        end
      end
      context 'with filename array whose size is smaller than contents' do
        it 'gets 3 still contents by given filename and 2 by original filename' do
          cam.transfer_contents contents, filenames[0, 3], dir: dir, size: 'large'
          expect(Dir.entries(dir).count { |e| e.match(/test_\d.JPG/) }).to eq(3)
          expect(Dir.entries(dir).count { |e| e.match(/DSC\d+\.JPG/) }).to eq(2)
        end
      end
      context 'with filename list > contents list' do
        it 'gets 3 still contents by given filenames' do
          cam.change_function_to_transfer
          cam.transfer_contents contents[0, 3], filenames, dir: dir
          expect(Dir.entries(dir).count { |e| e.match(/test_\d.JPG/) }).to eq(3)
        end
      end
      context 'with filename list being nil' do
        it 'gets 3 still contents by given filenames' do
          cam.change_function_to_transfer
          cam.transfer_contents contents, nil, dir: dir
          expect(Dir.entries(dir).count { |e| e.match(/DSC\d+\.JPG/) }).to eq(5)
        end
      end
      context 'with contents list being nil' do
        it 'does nothing' do
          cam.change_function_to_transfer
          cam.transfer_contents nil, nil
        end
      end
    end

    describe '#delete_contents' do
      context 'passed nil' do
        it 'does not delete anything' do
          cam.change_function_to_transfer
          cam.delete_contents nil
          contents_after = cam.get_content_list date: '20160803'
          expect(contents_after.size).to eq $NUM_ALL
        end
      end
      context 'passed content list' do
        before do
          cam.change_function_to_shoot 'still', 'Single'
          2.times do
            cam.capture_still transfer: false
          end
        end
        it 'deletes passed contents' do
          cam.change_function_to_transfer
          deleted = cam.get_content_list date: today
          expect(deleted.size).to eq 2
          cam.delete_contents deleted
          contents_after = cam.get_content_list date: today
          expect(contents_after.size).to eq 0
        end
      end
    end
  end
end
