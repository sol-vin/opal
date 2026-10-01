module Opal
  module CLI
    # Represents a positional argument for a command.
    class Argument
      getter name : Symbol
      getter description : String
      getter? required : Bool
      getter default : String?
      getter type : Symbol
      getter? multiple : Bool
      getter choices : Array(String)?
      getter value_name : String?

      def initialize(
        @name : Symbol,
        @description : String = "",
        @required : Bool = false,
        @default : String? = nil,
        @type : Symbol = :string,
        @multiple : Bool = false,
        @choices : Array(String)? = nil,
        @value_name : String? = nil,
      )
      end

      # Formatted argument display name (e.g. "<files...>" or "[files...]")
      def formatted_name : String
        base = @value_name || @name.to_s.upcase
        base = "#{base}..." if @multiple
        @required ? "<#{base}>" : "[#{base}]"
      end
    end
  end
end
