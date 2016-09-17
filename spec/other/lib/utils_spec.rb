require 'spec_helper'

module SonyCameraRemoteAPI
  describe Utils do
    let(:sbj) { SonyCameraRemoteAPI::Utils }

    describe '#print_list_in_columns' do
      let(:array) do
        [
            ' * Auto WB',
            ' * Daylight',
            ' * Shade',
            ' * Cloudy',
            ' * Incandescent',
            ' * Fluorescent: Warm White (-1)',
            ' * Fluorescent: Cool White (0)',
            ' * Fluorescent: Day White (+1)',
            ' * Fluorescent: Daylight (+2)',
            ' * Flash',
            '=> Color Temperature : 2500-9900, step=100',
            ' * Custom 1',
            ' * Custom 2',
            ' * Custom 3',
         ]
      end
      it 'print arrays' do
        puts '----------'
        sbj.print_array_in_columns(array, 120, 4, 10)
        puts '----------'
        sbj.print_array_in_columns(array, 120, 10, 10)
        puts '----------'
        sbj.print_array_in_columns(array, 140, 5, 100)
        puts '----------'
      end
    end


    describe '#get_next_file_number' do
      let(:prefix) { 'abc' }
      let(:dir) { 'images' }
      before :each do
        FileUtils.rm_r 'images' if Dir.exists? 'images'
        FileUtils.mkdir 'images'
      end
      after :each do
        FileUtils.rm_r 'images' if Dir.exists? 'images'
      end
      context 'when there is no files' do
        it 'returns 0' do
          num = sbj.get_next_file_number 'abc', 'JPG', dir: dir
          expect(num).to eq 0
        end
        it 'returns 7' do
          FileUtils.touch (0..6).map { |e| FileUtils.touch "#{dir}/#{prefix}_#{e}.JPG" }
          num = sbj.get_next_file_number prefix, 'JPG', dir: dir
          expect(num).to eq 7
        end
      end
    end
    describe '#generate_sequencial_filenames' do
      it 'returns sequencial filename' do
        gen = sbj.generate_sequencial_filenames 'abc', 'JPG'
        names = 3.times.map { |e| gen.next }
        expect(names).to match_array %w(abc_0.JPG abc_1.JPG abc_2.JPG)
      end
      it 'returns sequencial filename' do
        gen = sbj.generate_sequencial_filenames 'abc', 'JPG', start: 10
        names = 3.times.map { |e| gen.next }
        expect(names).to match_array %w(abc_10.JPG abc_11.JPG abc_12.JPG)
      end
      it 'returns sequencial filename' do
        names = sbj.generate_sequencial_filenames 'abc', 'JPG', start: 10, num: 4
        expect(names).to match_array %w(abc_10.JPG abc_11.JPG abc_12.JPG abc_13.JPG)
      end
    end

    describe '#partial_and_unique_match' do
      let(:candidates) { ['big', 'bigger', 'biggest', 'BIG'] }
      it 'returns result if 1 candidate is matched' do
        pattern = 'big'
        res, num = sbj.partial_and_unique_match(pattern, candidates)
        expect(res).to eq('big')
        expect(num).to eq(1)
        pattern = 'bigger'
        res, num = sbj.partial_and_unique_match(pattern, candidates)
        expect(res).to eq('bigger')
        expect(num).to eq(1)
      end
      it 'returns nil if the number of matched candidates is not equal to 1' do
        pattern = 'bi'
        res, num = sbj.partial_and_unique_match(pattern, candidates)
        expect(res).to eq(nil)
        expect(num).to eq(3)
      end
      it 'returns result if 1 candidate case-insensitively matches' do
        pattern = 'BIGGER'
        res, num = sbj.partial_and_unique_match(pattern, candidates)
        expect(res).to eq('bigger')
        expect(num).to eq(1)
        pattern = 'Est'
        res, num = sbj.partial_and_unique_match(pattern, candidates)
        expect(res).to eq('biggest')
        expect(num).to eq(1)
      end
    end
  end
end
