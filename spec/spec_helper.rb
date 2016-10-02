$TESTING = true

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'simplecov'
require 'sony_camera_remote_api'
require 'sony_camera_remote_api/scripts'
require 'sony_camera_remote_api/client/main'
require 'sony_camera_remote_api/utils'
require 'sony_camera_remote_api/shelf'
require 'io/console'
require 'fileutils'

# Global variables for contents test
$NUM_STILL  = 210
$NUM_MP4    = 6
$NUM_XAVCS  = 4
$NUM_ALL    = $NUM_STILL + $NUM_MP4 + $NUM_XAVCS
$NUM_STILL_3  = $NUM_STILL * 3
$NUM_MP4_3    = $NUM_MP4 * 3
$NUM_XAVCS_3  = $NUM_XAVCS * 3
$NUM_ALL_3    = $NUM_ALL * 3


# Get model name from --tag option
def get_model_tag
  rules = RSpec.world.filter_manager.inclusions.rules
  result = rules.find { |k,v| k.to_s.match /^[[:upper:]]/ }
  if result
    model_tag = result[0].to_s
    model_name = model_tag.tr '_', '-'
    [model_tag, model_name]
  else
    [nil, nil]
  end
end


# Delete all tags given by --tag option, if --only-failures option is present.
def delete_tags
  rules = RSpec.world.filter_manager.inclusions.rules
  if rules.find { |k,v| k == :last_run_status }
    rules.delete_if { |k,v| k != :last_run_status }
  end
end



RSpec.configure do |c|
  # c.fail_fast = true
  c.filter_run :focus
  c.run_all_when_everything_filtered = true
  c.example_status_persistence_file_path = "example_status.txt"

  # Variables in before(:suite) is not in the scope of examples.
  # So define here and assign them to instance variables in before(:all) below.
  model_tag, model_name = get_model_tag
  shelf = nil
  cam = nil
  client = nil
  cam_rcn = nil

  # Delete tags if --only-failures option is present.
  delete_tags


  # Initialize camera instance
  c.before(:suite) do
    unless model_tag
      puts 'No camera model specified!'
      cam = nil
    else
      # Camera model is present!
      # Wait user input to switch models
      puts "Specified model name: '#{model_name}'"
      puts 'Press any key to continue...'
      sound_ready
      STDIN.getch.chr

      # Select camera and connect using sonycam utility
      shelf = SonyCameraRemoteAPI::Shelf.new File.expand_path('~/.sonycam.shelf')
      shelf.select model_name
      unless shelf.connect
        puts 'ERROR: Test exited because wi-fi connection setup failed!'
        exit! 1
      end

      # Camera object for lib test
      cam = SonyCameraRemoteAPI::Camera.new shelf
      # Camera object for reconnection test
      cam_rcn = SonyCameraRemoteAPI::Camera.new shelf, reconnect_by: shelf.method(:connect)
      # Client class for client test
      client = SonyCameraRemoteAPI::Client::Main
    end
  end

  # Clean up transferred contents.
  c.after(:suite) do
    FileUtils.rm Dir['*.jpg']
    FileUtils.rm Dir['*.JPG']
    FileUtils.rm Dir['*.MP4']
    sound_complete
  end

  # Assgin to instance variable to use in examples.
  c.before(:all) do
    @model_tag = model_tag
    @mode_name = model_name
    @shelf = shelf
    @cam = cam
    @client = client
    @cam_rcn = cam_rcn
  end
end


# Capture the output to the stream
def capture(stream, put = false)
  begin
    stream = stream.to_s
    eval "$#{stream} = StringIO.new"
    yield
    result = eval("$#{stream}").string
  ensure
    eval("$#{stream} = #{stream.upcase}")
  end
  puts result if put
  result
end


# Capture the output of forked process executing given block
# After specified time elapses, the SIGINT is sent to the process to quit.
def capture_process(time)
  # Create child process to send Signal for interrupt.
  read, write = IO.pipe
  pid = fork do
    load '.simplecov'
    read.close
    output = capture(:stdout, true) { yield }
    Marshal.dump(output, write)
    exit 0
  end
  write.close
  puts "Sleeping #{time} sec..."
  sleep time
  # Send SIGINT and wait it finishes
  Process.kill :INT, pid
  Process.waitpid(pid)
  # Get output
  Marshal.load(read.read)
end


# This matcher tests exit code.
# If block did not call exit, it is regarded to have exited with code 0.
RSpec::Matchers.define :exit_with_code do |code|
  actual = nil
  match do |block|
    begin
      block.call
    rescue SystemExit => e
      actual = e.status
    end
    actual = actual.nil? ? 0 : actual
    actual && actual == code
  end

  def supports_block_expectations?
    true
  end

  failure_message_when_negated do |_block|
    "expected block to call exit(#{code}) but exit" + (actual.nil? ? ' not called' : "(#{actual}) was called")
  end

  failure_message do |_block|
    "expected block not to call exit(#{code})"
  end

  description do
    "expect block to call exit(#{code})"
  end
end


RSpec::Matchers.define_negated_matcher :not_change, :change


# Some camera has hardware mode dial to change shoot mode, which oblige us switch it physically.
# This method try to change shoot mode, and if failed, prompt us to switch mode dial.
def set_mode_dial(cam, shoot_mode, exposure_mode=nil)
  message = false
  if shoot_mode
    if cam.get_current!(:ShootMode) != shoot_mode
      if cam.set_parameter!(:ShootMode, shoot_mode)[:current] != shoot_mode
        message = true
      end
    end
  end

  if exposure_mode
    if cam.get_current!(:ExposureMode) != exposure_mode
      if cam.set_parameter!(:ExposureMode, exposure_mode)[:current] != exposure_mode
          message = true
      end
    end
  end

  if message
    if exposure_mode
      puts "Set mode-dial to '#{exposure_mode}' and press any key..."
    else
      puts "Set mode-dial to '#{shoot_mode}' and press any key..."
    end
    bell_and_getch
  end
end


def focus_somewhere(cam)
  def pos
    rand(101)
  end
  set_mode_dial cam, 'still'
  unless cam.focused?
    loop do
      puts 'Trying to focus somewhere...'
      break if cam.act_touch_focus pos, pos
    end
  end
end


# These method works only in Ubuntu
def bell
  system('paplay /usr/share/sounds/freedesktop/stereo/bell.oga --volume 100000')
end

def sound_complete
  system('paplay /usr/share/sounds/freedesktop/stereo/complete.oga --volume 125000')
end

def sound_ready
  system('paplay /usr/share/sounds/ubuntu/stereo/system-ready.ogg --volume 100000')
end

def bell_and_getch
  bell
  puts STDIN.getch.chr
end


