# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'execjs/fastnode/version'

Gem::Specification.new do |spec|
  spec.name          = "execjs-fastnode"
  spec.version       = ExecJS::FastNode::VERSION
  spec.authors       = ["John Hawthorn"]
  spec.email         = ["john.hawthorn@gmail.com"]

  spec.summary       = %q{A faster implementation of ExecJS's node runtime}
  spec.description   = %q{An ExecJS node runtime which uses pipes to avoid repeated startup costs}
  spec.homepage      = "https://github.com/jhawthorn/execjs-fastnode"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "execjs", "~> 2.0"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
end
