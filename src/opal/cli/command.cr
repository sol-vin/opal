require "./option"
require "./argument"
require "./context"
require "./help"

module Opal
  module CLI
    # Represents a custom section in command help screens (e.g. PIPING EXAMPLES)
    class HelpSection
      getter title : String
      getter lines : Array(String)

      def initialize(@title : String)
        @lines = [] of String
      end

      def text(t : String) : self
        @lines << t
        self
      end

      def example(ex : String) : self
        @lines << "  $ #{ex}"
        self
      end
    end

    # Represents a command or subcommand node in the CLI hierarchy.
    class Command
      property name : String
      property description : String
      property summary : String? = nil
      property title : String? = nil
      property header_text : String? = nil
      property footer_text : String? = nil
      property aliases : Array(String)
      property options : Array(Option)
      property arguments : Array(Argument)
      property subcommands : Hash(String, Command)
      property examples : Array(String)

      # Alias for subcommands
      def commands : Hash(String, Command)
        @subcommands
      end
      property sections : Array(HelpSection)
      property category : String? = nil
      property parent : Command? = nil
      property? allow_unknown_options : Bool = false
      property help_handler : (Context? -> String | Nil)? = nil

      @current_group : String? = nil

      # Allows unrecognized options or flags to pass through without parsing errors
      def allow_unknown_options(allow : Bool = true) : self
        @allow_unknown_options = allow
        self
      end

      # Registers a custom help handler for this command
      def on_help(&block : Context? -> String | Nil) : self
        @help_handler = block
        self
      end

      @before_hooks = [] of (Context -> Nil)
      @after_hooks = [] of (Context -> Nil)
      @action : (Context -> Nil | Int32)? = nil

      def initialize(@name : String, @description : String = "")
        @aliases = [] of String
        @options = [] of Option
        @arguments = [] of Argument
        @subcommands = {} of String => Command
        @examples = [] of String
        @sections = [] of HelpSection
      end

      # Sets short summary for parent command listings
      def summary(text : String) : self
        @summary = text
        self
      end

      # Sets display title
      def title(text : String) : self
        @title = text
        self
      end

      # Sets header/banner text
      def header(text : String) : self
        @header_text = text
        self
      end

      def banner(text : String) : self
        header(text)
      end

      # Sets footer/epilog text
      def footer(text : String) : self
        @footer_text = text
        self
      end

      def epilog(text : String) : self
        footer(text)
      end

      # Sets command category for grouped help rendering
      def category(cat : String) : self
        @category = cat
        self
      end

      def description(desc : String) : self
        @description = desc
        self
      end

      # Groups enclosed option/flag definitions into a named category
      def group(name : String, &block : -> Nil) : self
        prev = @current_group
        @current_group = name
        begin
          block.call
        ensure
          @current_group = prev
        end
        self
      end

      # Adds a custom help section (e.g. PIPELINE COMPOSITION)
      def section(title : String, &block : HelpSection -> Nil) : self
        sec = HelpSection.new(title)
        block.call(sec)
        @sections << sec
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

      # Defines a boolean flag (e.g. -q, --quiet or unified "-q, --quiet")
      def flag(
        name : Symbol,
        long : String,
        short : String? = nil,
        description : String = "",
        default : Bool = false,
        global : Bool = false,
      ) : self
        opt = if short.nil? && (long.includes?(',') || long.includes?(' '))
                Option.from_spec(
                  name: name,
                  spec: long,
                  description: description,
                  type: :bool,
                  default: default,
                  global: global,
                  group: @current_group
                )
              else
                Option.new(
                  name: name,
                  long: long,
                  short: short,
                  description: description,
                  type: :bool,
                  default: default,
                  global: global,
                  group: @current_group
                )
              end
        @options << opt
        self
      end

      # Defines a valued option (e.g. -e src/main.cr, --entry=src/main.cr or unified "-e, --entry=DIR")
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
        opt = if short.nil? && (long.includes?(',') || long.includes?(' ') || long.includes?('='))
                Option.from_spec(
                  name: name,
                  spec: long,
                  description: description,
                  type: type,
                  default: default,
                  required: required,
                  global: global,
                  choices: choices,
                  env_var: env_var,
                  group: @current_group
                )
              else
                Option.new(
                  name: name,
                  long: long,
                  short: short,
                  description: description,
                  type: type,
                  default: default,
                  required: required,
                  global: global,
                  choices: choices,
                  env_var: env_var,
                  group: @current_group
                )
              end
        @options << opt
        self
      end

      # Shorthand for option with unified spec string like "-d, --delimiter=CHAR"
      def opt(
        name : Symbol,
        spec : String,
        description : String = "",
        type : Symbol? = nil,
        default : OptionValue = nil,
        required : Bool = false,
        global : Bool = false,
        choices : Array(String)? = nil,
        env_var : String? = nil,
        group : String? = nil,
      ) : self
        opt = Option.from_spec(
          name: name,
          spec: spec,
          description: description,
          type: type,
          default: default,
          required: required,
          global: global,
          choices: choices,
          env_var: env_var,
          group: group || @current_group
        )
        @options << opt
        self
      end

      # Defines a positional argument
      def argument(
        name : Symbol,
        description : String = "",
        required : Bool = false,
        default : String? = nil,
        type : Symbol = :string,
        multiple : Bool = false,
        choices : Array(String)? = nil,
        value_name : String? = nil,
      ) : self
        @arguments << Argument.new(
          name: name,
          description: description,
          required: required,
          default: default,
          type: type,
          multiple: multiple,
          choices: choices,
          value_name: value_name
        )
        self
      end

      # Ergonomic shorthand for argument
      def arg(
        name : Symbol,
        description : String = "",
        required : Bool = false,
        default : String? = nil,
        type : Symbol = :string,
        multiple : Bool = false,
        choices : Array(String)? = nil,
        value_name : String? = nil,
      ) : self
        argument(
          name: name,
          description: description,
          required: required,
          default: default,
          type: type,
          multiple: multiple,
          choices: choices,
          value_name: value_name
        )
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
      def help_text(app_name : String, context : Context? = nil) : String
        if handler = @help_handler
          res = handler.call(context)
          return res.is_a?(String) ? res : ""
        end
        Help.render_command(
          app_name: app_name,
          command: self,
          context: context
        )
      end
    end
  end
end
