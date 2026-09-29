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
      )
        clean_long = long.split(/[\s=\[<]/).first
        @long = clean_long.starts_with?("--") ? clean_long : "--#{clean_long}"

        @short = if short
                   clean_short = short.split(/[\s=\[<]/).first
                   clean_short.starts_with?("-") ? clean_short : "-#{clean_short}"
                 else
                   nil
                 end

        # If no default is provided for bool, default is false
        if @type == :bool && @default.nil?
          @default = false
        end
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
          val_placeholder = @name.to_s.upcase
          parts << "#{@long}=#{val_placeholder}"
        end
        parts.join(", ")
      end
    end
  end
end
