# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sony_camera_remote_api/version'

Gem::Specification.new do |spec|
  spec.name          = "sony_camera_remote_api"
  spec.version       = SonyCameraRemoteAPI::VERSION
  spec.authors       = ["kota65535"]
  spec.email         = ["kota65535@gmail.com"]

  spec.summary       = %q{A Ruby Gem that facilitates the use of Sony Remote Camera API.}
  # spec.description   = %q{A Ruby Gem that facilitates the use of Sony Remote Camera API.}
  spec.homepage      = "https://github.com/kota65535/sony_camera_remote_api"
  spec.license       = "MIT"


  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5"
  spec.add_development_dependency "simplecov"

  spec.add_dependency "activesupport"
  spec.add_dependency "frisky"
  spec.add_dependency "httpclient"
  spec.add_dependency "nokogiri"
  spec.add_dependency "bindata"
  spec.add_dependency "thor"
  spec.add_dependency "highline"
end
