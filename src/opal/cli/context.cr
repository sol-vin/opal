require "./option"

module Opal
  module CLI
    # Context passed into command run blocks containing resolved arguments and flags.
    class Context
      getter flags : Hash(Symbol, Bool)
      getter options : Hash(Symbol, OptionValue)
      getter args : Array(String)
      getter named_args : Hash(Symbol, String)
      getter raw_args : Array(String)

      def initialize(
        @flags = Hash(Symbol, Bool).new,
        @options = Hash(Symbol, OptionValue).new,
        @args = Array(String).new,
        @named_args = Hash(Symbol, String).new,
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
    end
  end
end
