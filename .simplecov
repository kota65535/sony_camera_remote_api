if !ENV['COVERAGE'].nil?
  SimpleCov.start do
    add_filter '/spec'
    # Merge all tests run in 2 hours
    use_merging true
    merge_timeout 7200
    command_name "cmd_#{Time.now}"
    puts 'SimpleCov started!!!'
    # minimum_coverage(91.69)
  end

  # For forked process
  SimpleCov.at_exit do
    SimpleCov.result.format!
  end
end
