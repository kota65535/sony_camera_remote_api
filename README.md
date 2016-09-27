# Sony Camera Remote API Wrapper

A Ruby Gem that facilitates the use of Sony Camera Remote API.

- [Backgrounds](#backgrounds)
- [Features](#features)
- [Supported version](#supported-version)
- [Installation](#installation)
- [Usage](#usage)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)


## Backgrounds

[Sony Camera Remote API](https://developer.sony.com/develop/cameras/) allows us to control a number of Sony cameras, including Sony Action cams, Sony Alpha cameras and Lens Style cameras, wirelessly from another device.
But these APIs are quite low-level, so that we have to implement a lot of sequences while considering many pitfalls, which are less documented in their API reference.
This gem is a wrapper library that make it easy to use Sony camera functions for high-level applications.


## Features

* Streaming live-view images by one method
* Simplified contents transfer
* Consistent interface for changing parameters safely
* Auto reconnection
* Also supports the low-level APIs call
* Client application bundled


## Supported version

Ruby 2.0 or higher

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sony_camera_remote_api'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install sony_camera_remote_api


## Usage

1. Connect your PC (or device) to the camera with Direct Wi-Fi. If you are using Linux, it is recommended to use
   Shelf class like the following example.
2. Create SonyCameraRemoteAPI::Camera instance with Shelf instance.
3. Now you can access all of camera APIs and useful wrapper methods!

This is an example code of capturing single still image.

```ruby
require 'sony_camera_remote_api'

interface = "wlan0"
ssid = "DIRECT-xxxx:ILCE-QX1"
pass = "xxxxxxxx"

shelf = SonyCameraRemoteAPI::Shelf.new 'sonycam.shelf'
shelf.add_and_select ssid, pass, interface
shelf.connect

cam = SonyCameraRemoteAPI::Camera.new shelf
cam.change_function_to_shoot 'still', 'Single'
cam.capture_still
# => Captured jpeg file is transferred to your PC
```

For more information, see project's [Wiki](https://github.com/kota65535/sony_camera_remote_api/wiki).


## TODO

* Remote playback function


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kota65535/sony_camera_remote_api. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
