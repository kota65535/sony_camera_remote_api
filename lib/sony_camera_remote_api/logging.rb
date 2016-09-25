require 'logger'

# Logging function module
module Logging
  # Generic delegator class
  class MultiDelegator
    def initialize(*targets)
      @targets = targets
    end

    def self.delegate(*methods)
      methods.each do |m|
        define_method(m) do |*args|
          @targets.map { |t| t.send(m, *args) }
        end
      end
      self
    end

    class <<self
      alias to new
    end
  end

  #--------------------PUBLIC METHODS BEGIN--------------------

  # Get Logger class instance for the user class.
  # @return [Logger] Logging class instance
  def log
    @logger ||= Logging.logger_for(self.class.name)
  end


  # Set file name or stream to output log.
  # Log file is common in each user class.
  # @param [String, IO, Array<String, IO>] log_file file name or stream to output log.
  # @return [void]
  def set_output(*log_file)
    Logging.log_file self.class.name, log_file
  end

  # Set log level.
  # @param [Fixnum] level Log level for Logger object.
  def set_level(level)
    @@level = level
  end

  #--------------------PUBLIC METHODS END----------------------


  # Log files and streams shared in user classes.
  @log_file = []
  # Use a hash class-ivar to cache a unique Logger per class.
  @loggers = {}

  @@level = Logger::DEBUG

  # These module class methods are private to user class.
  class << self
    # Set log files and streams. Logger class instance is re-created.
    def log_file(classname, log_file)
      @log_file = Array(log_file)
      @loggers[classname] = nil
    end

    # Get Logger class instance or create it for the user class
    def logger_for(classname)
      @loggers[classname] ||= configure_logger_for(classname)
    end

    # Configure Logger instance for the user class.
    # 1. create Logger instance with given log file and sterams
    # 2. set progname to user class name
    def configure_logger_for(classname)
      @log_file.compact!
      fios = @log_file.map do |f|
        f.is_a?(String) ? File.open(f, 'a') : f
      end
      logger = Logger.new MultiDelegator.delegate(:write, :close).to(*fios)
      logger.progname = classname.split('::')[-1]
      logger.level = @@level
      logger
    end
  end
end
