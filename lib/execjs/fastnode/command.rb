module ExecJS
  module FastNode
    class Command
      def initialize(command)
        @command = command
      end

      def to_cmd
        which
      end

      private

      def locate_executable(command)
        commands = Array(command)
        if ExecJS.windows? && File.extname(command) == ""
          ENV['PATHEXT'].split(File::PATH_SEPARATOR).each { |p|
            commands << (command + p)
          }
        end

        commands.find { |cmd|
          if File.executable? cmd
            cmd
          else
            path = ENV['PATH'].split(File::PATH_SEPARATOR).find { |p|
              full_path = File.join(p, cmd)
              File.executable?(full_path) && File.file?(full_path)
            }
            path && File.expand_path(cmd, path)
          end
        }
      end

      def which
        Array(@command).find do |name|
          name, args = name.split(/\s+/, 2)
          path = locate_executable(name)

          next unless path

          args ? "#{path} #{args}" : path
        end
      end
    end
  end
end
