require "execjs/fastnode/version"
require "execjs/fastnode/external_piped_runtime"
require "execjs/runtimes"

module ExecJS
  module Runtimes
    # re-opening the runtimes class
    FastNode = FastNode::ExternalPipedRuntime.new(
      name:        "Node.js (V8) fast",
      command:     ["nodejs", "node"],
      runner_path: File.expand_path('../../fastnode/node_piped_runner.js', __FILE__),
      encoding:    'UTF-8'
    )

    # Place FastNode runtime first
    runtimes.unshift(FastNode)
  end
end
