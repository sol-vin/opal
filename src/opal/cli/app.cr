require "./command"
require "./parser"
require "./completion"

module Opal
  module CLI
    # Root CLI application that manages command routing, help, versions, and execution.
    class App < Command
      property version : String

      def initialize(name : String, @version : String = "0.1.0")
        super(name)
        # Built-in global flags
        flag :help, "--help", "-h", description: "Show help screen", global: true
        flag :version, "--version", "-v", description: "Show application version", global: true
      end

      # Runs the CLI with arguments (defaults to ARGV) and returns an exit code.
      def run(args : Array(String) = ARGV) : Int32
        if args.empty?
          puts help_text(@name)
          return 0
        end

        # Handle top-level help command (e.g. `lapis help build`)
        if args[0] == "help"
          if args.size > 1
            target_sub = find_command(args[1])
            if target_sub
              puts target_sub.help_text(@name)
              return 0
            else
              STDERR.puts "\e[31mError:\e[0m Unknown command for help: '#{args[1]}'"
              puts
              puts help_text(@name)
              return 1
            end
          else
            puts help_text(@name)
            return 0
          end
        end

        # Handle top-level version command
        if args.size == 1 && (args[0] == "version" || args[0] == "-v" || args[0] == "--version")
          puts "#{@name} v#{@version}"
          return 0
        end

        # Handle autocompletion generation
        if args[0] == "completion"
          shell = args.size > 1 ? args[1].downcase : "bash"
          case shell
          when "bash" then puts Completion.bash(@name, self)
          when "zsh"  then puts Completion.zsh(@name, self)
          when "fish" then puts Completion.fish(@name, self)
          else
            STDERR.puts "Supported shells: bash, zsh, fish"
            return 1
          end
          return 0
        end

        begin
          target_command, context = Parser.parse(self, args)

          if context.flag?(:help)
            puts target_command.help_text(@name)
            return 0
          end

          if context.flag?(:version)
            puts "#{@name} v#{@version}"
            return 0
          end

          target_command.execute(context)
        rescue ex : ParseError
          STDERR.puts "\e[31mError:\e[0m #{ex.message}"
          puts
          puts help_text(@name)
          1
        rescue ex : Exception
          STDERR.puts "\e[31mUnhandled Error:\e[0m #{ex.message}"
          1
        end
      end
    end
  end
end
