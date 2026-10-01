require "./option"

module Opal
  module CLI
    # Context passed into command run blocks containing resolved arguments and flags.
    class Context
      getter flags : Hash(Symbol, Bool)
      getter options : Hash(Symbol, OptionValue)
      getter args : Array(String)
      getter named_args : Hash(Symbol, String)
      getter named_arg_lists : Hash(Symbol, Array(String))
      getter raw_args : Array(String)
      @cached_stdin : String? = nil
      @stdin_read : Bool = false

      def initialize(
        @flags = Hash(Symbol, Bool).new,
        @options = Hash(Symbol, OptionValue).new,
        @args = Array(String).new,
        @named_args = Hash(Symbol, String).new,
        @named_arg_lists = Hash(Symbol, Array(String)).new,
        @raw_args = Array(String).new,
      )
      end

      # Returns true if flag was specified
      def flag?(name : Symbol) : Bool
        @flags[name]? == true
      end

      # Retrieves an option by name
      def [](name : Symbol) : OptionValue
        @options[name]?
      end

      def []?(name : Symbol) : OptionValue
        @options[name]?
      end

      # Strongly-typed string getter
      def string?(name : Symbol) : String?
        val = @options[name]?
        val.is_a?(String) ? val : nil
      end

      def string(name : Symbol) : String
        string?(name) || ""
      end

      # Strongly-typed int getter
      def int?(name : Symbol) : Int32?
        val = @options[name]?
        if val.is_a?(Int32)
          val
        elsif val.is_a?(String)
          val.to_i?
        else
          nil
        end
      end

      def int(name : Symbol) : Int32
        int?(name) || 0
      end

      # Strongly-typed float getter
      def float?(name : Symbol) : Float64?
        val = @options[name]?
        if val.is_a?(Float64)
          val
        elsif val.is_a?(Int32)
          val.to_f64
        elsif val.is_a?(String)
          val.to_f64?
        else
          nil
        end
      end

      def float(name : Symbol) : Float64
        float?(name) || 0.0
      end

      # Strongly-typed array getter
      def array(name : Symbol) : Array(String)
        val = @options[name]?
        val.is_a?(Array(String)) ? val : [] of String
      end

      # Retrieves a positional argument by name
      def arg(name : Symbol) : String?
        @named_args[name]?
      end

      def arg!(name : Symbol) : String
        @named_args[name]? || raise ArgumentError.new("Missing required argument: #{name}")
      end

      # Retrieves an array of positional arguments for variadic definitions
      def arg_list(name : Symbol) : Array(String)
        @named_arg_lists[name]? || (@named_args[name]?.try { |v| [v] } || [] of String)
      end

      # Retrieves all variadic or positional arguments without specifying a name
      def arg_list : Array(String)
        if first_list = @named_arg_lists.first_value?
          first_list
        else
          @args
        end
      end

      # Returns true if STDIN is piped or redirected
      def pipe? : Bool
        !(STDIN.tty? rescue true)
      end

      # Reads content from STDIN lazily and caches the result
      def stdin_content : String?
        return @cached_stdin if @stdin_read
        @stdin_read = true
        if pipe?
          @cached_stdin = STDIN.gets_to_end rescue nil
        end
        @cached_stdin
      end

      # Unified input reader: checks explicit argument first (file, '-', or text),
      # and falls back to STDIN pipe if no argument was passed.
      def read_input_or_arg(arg_name : Symbol? = nil) : String?
        arg_val = arg_name ? arg(arg_name) : nil
        if arg_val.nil? && !@args.empty? && arg_name.nil?
          arg_val = @args.first?
        end

        if arg_val
          if arg_val == "-"
            return STDIN.gets_to_end rescue nil
          elsif File.exists?(arg_val)
            return File.read(arg_val) rescue nil
          else
            return arg_val
          end
        end

        # Fallback to STDIN pipe if available
        stdin_content
      end
    end
  end
end
