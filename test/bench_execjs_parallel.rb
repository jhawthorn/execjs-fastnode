require 'benchmark'
require 'parallel'
require 'execjs'

TIMES = 100
SOURCE = File.read(File.expand_path("../fixtures/coffee-script.js", __FILE__)).freeze

Benchmark.bmbm do |x|
  ExecJS::Runtimes.runtimes.each do |runtime|
    next if !runtime.available? || runtime.deprecated?

    x.report(runtime.name) do
      ExecJS.runtime = runtime
      context = ExecJS.compile(SOURCE)

      Parallel.each((1..TIMES).to_a, in_threads: 8) do
        context.call("CoffeeScript.eval", "((x) -> x * x)(8)")
      end
    end
  end
end
