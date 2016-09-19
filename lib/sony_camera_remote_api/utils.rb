module SonyCameraRemoteAPI
  # Module providing utility methods
  module Utils

    module_function

    # Get file name in the format of <prefix>_<num>.<ext>
    # If there are files that matches this format, get the next number of it.
    # @param [String] prefix
    # @param [String] ext
    # @param [Fixnum] start
    # @param [Fixnum] num
    # @param [String] dir
    def generate_sequencial_filenames(prefix, ext, start: nil, num: nil, dir: nil)
      if start
        count = start
      else
        count = get_next_file_number prefix, ext, dir: dir
      end
      gen = Enumerator.new do |y|
        loop do
          y << "#{prefix}_#{count}.#{ext}"
          count += 1
        end
      end
      if num
        return (0..(num-1)).map { gen.next }
      else
        return gen
      end
    end


    # Get the next file number by searching files with format '<prefix>_\d+.<ext>' in <dir>.
    # @param [String] prefix
    # @param [String] ext
    # @param [String] dir
    def get_next_file_number(prefix, ext, dir: nil)
      numbers = []
      Dir["#{dir}/*"].map do |f|
        begin
          num = f[/#{dir}\/#{prefix}_(\d+).#{ext}/, 1]
          numbers << num.to_i if num.present?
        rescue
          nil
        end
      end
      if numbers.empty?
        0
      else
        numbers.sort[-1] + 1
      end
    end


    # Search pattern in candidates.
    # @param [String] pattern Pattern
    # @param [Array<String>] candidates Candidates
    # @return [Array<String, Fixnum>] matched candidate and the number of matched candidates.
    def partial_and_unique_match(pattern, candidates)
      result = candidates.find { |c| c == pattern }
      return result, 1 if result
      result = candidates.select { |c| c =~ /#{pattern}/i }
      return result[0], 1 if result.size == 1
      result = candidates.select { |c| c =~ /#{pattern}/ }
      return result[0], 1 if result.size == 1
      return nil, result.size
    end


    # Print array.
    # @param [Array] array
    # @param [Fixnum] horizon
    # @param [Fixnum] space
    # @param [Fixnum] threshold
    def print_array_in_columns(array, horizon, space, threshold)
      if array.size >= threshold
        longest = array.map { |s| s.size }.max
        num_columns = (horizon + space ) / (longest + space)
        num_rows = array.size / num_columns + 1
        array += [''] * ((num_columns * num_rows) - array.size)
        array_2d = array.each_slice(num_rows).to_a
        longests = array_2d.map { |column| column.map { |e| e.size }.max }
        array_2d = array_2d.transpose
        array_2d.each do |row|
          row.zip(longests).each do |e, len|
            print e + ' ' * (len - e.size) + ' ' * space
          end
          puts ''
        end
      else
        array.each do |e|
            puts e
        end
      end
    end
  end
end

