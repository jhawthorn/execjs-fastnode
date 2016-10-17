require "tmpdir"
require 'json'
require "open3"
require "execjs/runtime"
require "execjs/fastnode/command"

module ExecJS
  module FastNode
    class ExternalPipedRuntime < ExecJS::Runtime
      class VM
        attr_reader :stdin, :stdout

        def initialize(options)
          @stdin, @stdout, @wait_thr = Open3.popen2(options[:binary], options[:runner_path])

          ObjectSpace.define_finalizer(self, self.class.finalize(@stdin))
        end

        def self.finalize(stdin)
          proc { stdin.puts('{"cmd": "exit", "arguments": [0]}') }
        end

        def exec(context, source)
          command("exec", {context: context, source: source})
        end

        def delete_context(context)
          command("deleteContext", context)
        end

        def command(cmd, *arguments)
          @stdin.puts(::JSON.generate({cmd: cmd, args: arguments}))
          result = ::JSON.parse(@stdout.gets, create_additions: false)
        end
      end

      class Context < Runtime::Context
        def initialize(runtime, source = "", options = {})
          @runtime = runtime
          @uuid = SecureRandom.uuid

          ObjectSpace.define_finalizer(self, self.class.finalize(@runtime, @uuid))

          source = encode(source)

          raw_exec(source)
        end

        def self.finalize(runtime, uuid)
          proc { runtime.vm.delete_context(uuid) }
        end

        def eval(source, options = {})
          if /\S/ =~ source
            raw_exec("(#{source})")
          end
        end

        def exec(source, options = {})
          raw_exec("(function(){#{source}})()")
        end

        def raw_exec(source, options = {})
          source = encode(source)

          result = @runtime.vm.exec(@uuid, source)
          extract_result(result)
        end

        def call(identifier, *args)
          eval "#{identifier}.apply(this, #{::JSON.generate(args)})"
        end

        protected

        def extract_result(output)
          status, value, stack = output
          if status == "ok"
            value
          else
            stack ||= ""
            stack = stack.split("\n").map do |line|
              line.sub(" at ", "").strip
            end
            stack.reject! { |line| ["eval code", "eval@[native code]"].include?(line) }
            stack.shift unless stack[0].to_s.include?("(execjs)")
            error_class = value =~ /SyntaxError:/ ? RuntimeError : ProgramError
            error = error_class.new(value)
            error.set_backtrace(stack + caller)
            raise error
          end
        end
      end

      attr_reader :name, :vm

      def initialize(options)
        @name        = options[:name]
        @command     = Command.new(options[:command])
        @runner_path = options[:runner_path]
        @encoding    = options[:encoding]
        @deprecated  = !!options[:deprecated]
        @binary      = nil

        @popen_options = {}
        @popen_options[:external_encoding] = @encoding if @encoding
        @popen_options[:internal_encoding] = ::Encoding.default_internal || 'UTF-8'
      end

      def vm
        @vm ||= VM.new(
          binary: @binary,
          runner_path: @runner_path
        )
      end

      def available?
        binary ? true : false
      end

      def deprecated?
        @deprecated
      end

      private
      def binary
        @binary ||= @command.to_cmd
      end
    end
  end
end
