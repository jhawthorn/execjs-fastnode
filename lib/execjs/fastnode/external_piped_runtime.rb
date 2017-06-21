require "net/http"
require "securerandom"
require "socket"
require "thread"
require "tmpdir"
require 'json'
require "execjs/runtime"
require "execjs/fastnode/command"

module ExecJS
  module FastNode
    class ExternalPipedRuntime < ExecJS::Runtime
      class VMCommand
        def initialize(socket_path, cmd, arguments)
          @socket_path = socket_path.to_s
          @cmd = cmd
          @arguments = arguments
        end

        def execute
          sock = Net::BufferedIO.new(socket)

          request = Net::HTTP::Post.new("/")
          request['Connection'] = 'close'
          request['Content-Type'] = 'application/json'
          request.body = contents
          request.exec(sock, "1.1", "/")

          begin
            response = Net::HTTPResponse.read_new(sock)
          end while response.kind_of?(Net::HTTPContinue)

          response.reading_body(sock, request.response_body_permitted?) { }
          sock.close

          parse(response.body)
        end

        private

        def socket
          UNIXSocket.new(@socket_path)
        end

        def contents
          ::JSON.generate({cmd: @cmd, args: @arguments})
        end

        def parse(body)
          ::JSON.parse(body, create_additions: false)
        end
      end

      class VM
        def initialize(options)
          @mutex = Mutex.new
          @socket_path = nil
          @options = options
        end

        def started?
          !!@socket_path
        end

        def self.finalize(socket_path)
          proc {
            VMCommand.new(socket_path, "exit", [0]).execute
          }
        end

        def exec(context, source)
          command("exec", {context: context, source: source})
        end

        def delete_context(context)
          command("deleteContext", context)
        end

        def start
          @mutex.synchronize do
            start_without_synchronization
          end
        end

        private

        def start_without_synchronization
          return if started?
          dir = Dir.mktmpdir("execjs-fastnode-")
          @socket_path = File.join(dir, "socket")
          @pid = Process.spawn({"PORT" => @socket_path.to_s}, @options[:binary], @options[:runner_path])

          retries = 20
          while !File.exists?(@socket_path)
            sleep 0.05
            retries -= 1

            if retries == 0
              raise "Unable to start nodejs process"
            end
          end

          ObjectSpace.define_finalizer(self, self.class.finalize(@socket_path))
        end

        def command(cmd, *arguments)
          @mutex.synchronize do
            start_without_synchronization
            VMCommand.new(@socket_path, cmd, arguments).execute
          end
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

        @vm = VM.new(
          binary: binary,
          runner_path: @runner_path
        )

        @popen_options = {}
        @popen_options[:external_encoding] = @encoding if @encoding
        @popen_options[:internal_encoding] = ::Encoding.default_internal || 'UTF-8'
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
