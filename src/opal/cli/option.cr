module Opal
  module CLI
    alias OptionValue = String | Int32 | Float64 | Bool | Array(String) | Nil

    # Represents a command-line flag or option.
    class Option
      getter name : Symbol
      getter short : String?
      getter long : String
      getter description : String
      getter type : Symbol # :bool, :string, :int, :float, :array
      getter default : OptionValue
      getter? required : Bool
      getter? global : Bool
      getter choices : Array(String)?
      getter env_var : String?
      property group : String?
      getter value_name : String?

      def initialize(
        @name : Symbol,
        long : String,
        short : String? = nil,
        @description : String = "",
        @type : Symbol = :string,
        @default : OptionValue = nil,
        @required : Bool = false,
        @global : Bool = false,
        @choices : Array(String)? = nil,
        @env_var : String? = nil,
        @group : String? = nil,
        @value_name : String? = nil,
      )
        clean_long = long.split(/[\s=\[<]/).first
        @long = clean_long.starts_with?("--") ? clean_long : "--#{clean_long}"

        @short = if short
                   clean_short = short.split(/[\s=\[<]/).first
                   clean_short.starts_with?("-") ? clean_short : "-#{clean_short}"
                 else
                   nil
                 end

        # If value_name was embedded in long or short (e.g. "--delimiter=CHAR")
        if @value_name.nil?
          if long.includes?('=')
            @value_name = long.partition('=').last
          elsif long.includes?(' ')
            @value_name = long.partition(' ').last
          end
        end

        # If no default is provided for bool, default is false
        if @type == :bool && @default.nil?
          @default = false
        end
      end

      # Parses a unified spec string like "-d, --delimiter=CHAR" or "-z, --zebra"
      def self.from_spec(
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
      ) : Option
        tokens = spec.split(/,\s*|\s+/)
        short_val : String? = nil
        long_val : String? = nil
        val_name : String? = nil
        has_val = spec.includes?('=') || spec.includes?('<') || spec.includes?('[')

        tokens.each do |tok|
          if tok.starts_with?("--")
            part = tok.split(/[\s=\[<]/).first
            long_val = part
            if tok.includes?('=')
              val_name = tok.partition('=').last.rstrip(']')
            end
          elsif tok.starts_with?('-')
            part = tok.split(/[\s=\[<]/).first
            short_val = part
          end
        end

        resolved_long = long_val || "--#{name}"
        resolved_type = type || (has_val ? :string : :bool)

        new(
          name: name,
          long: resolved_long,
          short: short_val,
          description: description,
          type: resolved_type,
          default: default,
          required: required,
          global: global,
          choices: choices,
          env_var: env_var,
          group: group,
          value_name: val_name
        )
      end

      def flag? : Bool
        @type == :bool
      end

      # Formatted flag representation for help screens (e.g. "-e, --entry=DIR")
      def formatted_flag : String
        parts = [] of String
        if s = @short
          parts << s
        end
        if flag?
          parts << @long
        else
          val_placeholder = @value_name || @name.to_s.upcase
          parts << "#{@long}=#{val_placeholder}"
        end
        parts.join(", ")
      end

      # Alias for short
      def short_name : String?
        @short
      end

      # Alias for long
      def long_name : String
        @long
      end
    end
  end
end
