require "execjs/fastnode/version"

# Insert our new runtime into the list
require "execjs/fastnode/runtimes"

# Re-detect runtime
require 'execjs'
ExecJS.runtime = ExecJS::Runtimes.autodetect
