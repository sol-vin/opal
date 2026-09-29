require "./option"
require "./argument"
require "./context"
require "./help"

module Opal
  module CLI
    # Represents a command or subcommand node in the CLI hierarchy.
    class Command
      property name : String
      property description : String
      property aliases : Array(String)
      property options : Array(Option)
      property arguments : Array(Argument)
      property subcommands : Hash(String, Command)
      property examples : Array(String)
      property category : String? = nil
      property parent : Command? = nil

      @before_hooks = [] of (Context -> Nil)
      @after_hooks = [] of (Context -> Nil)
      @action : (Context -> Nil | Int32)? = nil

      def initialize(@name : String, @description : String = "")
        @aliases = [] of String
        @options = [] of Option
        @arguments = [] of Argument
        @subcommands = {} of String => Command
        @examples = [] of String
      end

      # Sets command description
            # Sets command category for grouped help rendering
      def category(cat : String) : self
        @category = cat
        self
      end

      def description(desc : String) : self
        @description = desc
        self
      end

      # Adds alias names for this command
      def alias_name(*names : String) : self
        names.each { |n| @aliases << n }
        self
      end

      # Defines a subcommand without a block
      def command(name : String | Symbol, description : String = "") : Command
        cmd = Command.new(name.to_s, description)
        cmd.parent = self
        @subcommands[cmd.name] = cmd
        cmd
      end

      # Defines a subcommand with a configuration block
      def command(name : String | Symbol, description : String = "", &block : Command -> Nil) : Command
        cmd = command(name, description)
        block.call(cmd)
        cmd.aliases.each do |a|
          @subcommands[a] = cmd
        end
        cmd
      end

      # Alias for command
      def subcommand(name : String | Symbol, description : String = "") : Command
        command(name, description)
      end

      def subcommand(name : String | Symbol, description : String = "", &block : Command -> Nil) : Command
        command(name, description, &block)
      end

      # Defines a boolean flag (e.g. -q, --quiet)
      def flag(
        name : Symbol,
        long : String,
        short : String? = nil,
        description : String = "",
        default : Bool = false,
        global : Bool = false,
      ) : self
        @options << Option.new(
          name: name,
          long: long,
          short: short,
          description: description,
          type: :bool,
          default: default,
          global: global
        )
        self
      end

      # Defines a valued option (e.g. -e src/main.cr, --entry=src/main.cr)
      def option(
        name : Symbol,
        long : String,
        short : String? = nil,
        description : String = "",
        type : Symbol = :string,
        default : OptionValue = nil,
        required : Bool = false,
        global : Bool = false,
        choices : Array(String)? = nil,
        env_var : String? = nil,
      ) : self
        @options << Option.new(
          name: name,
          long: long,
          short: short,
          description: description,
          type: type,
          default: default,
          required: required,
          global: global,
          choices: choices,
          env_var: env_var
        )
        self
      end

      # Defines a positional argument
      def argument(
        name : Symbol,
        description : String = "",
        required : Bool = false,
        default : String? = nil,
        type : Symbol = :string,
      ) : self
        @arguments << Argument.new(
          name: name,
          description: description,
          required: required,
          default: default,
          type: type
        )
        self
      end

      # Adds a usage example
      def example(ex : String) : self
        @examples << ex
        self
      end

      # Adds a hook before execution
      def before(&block : Context -> Nil) : self
        @before_hooks << block
        self
      end

      # Adds a hook after execution
      def after(&block : Context -> Nil) : self
        @after_hooks << block
        self
      end

      # Defines the execution body for this command
      def run(&block : Context -> Nil | Int32) : self
        @action = block
        self
      end

      # Executes this command with the provided context
      def execute(context : Context) : Int32
        # Run parent before hooks first
        @parent.try(&.execute_before_hooks(context))
        execute_before_hooks(context)

        code = if act = @action
                 res = act.call(context)
                 res.is_a?(Int32) ? res : 0
               else
                 0
               end

        execute_after_hooks(context)
        @parent.try(&.execute_after_hooks(context))

        code
      end

      protected def execute_before_hooks(context : Context) : Nil
        @before_hooks.each(&.call(context))
      end

      protected def execute_after_hooks(context : Context) : Nil
        @after_hooks.each(&.call(context))
      end

      # Collects all available options including inherited global options
      def all_options : Array(Option)
        result = @options.dup
        curr = @parent
        while curr
          curr.options.select { |o| o.global? || curr.parent.nil? }.each do |g_opt|
            unless result.any? { |o| o.name == g_opt.name }
              result << g_opt
            end
          end
          curr = curr.parent
        end
        result
      end

      # Finds a subcommand by name or alias
      def find_command(name : String) : Command?
        @subcommands[name]?
      end

      # Formats help screen for this command
      def help_text(app_name : String) : String
        Help.render(
          app_name: app_name,
          command_name: @name,
          description: @description,
          subcommands: @subcommands.reject { |k, v| k != v.name },
          options: all_options,
          arguments: @arguments,
          examples: @examples
        )
      end
    end
  end
end
