module Opal
  module CLI
    # Represents a positional argument for a command.
    class Argument
      getter name : Symbol
      getter description : String
      getter? required : Bool
      getter default : String?
      getter type : Symbol

      def initialize(
        @name : Symbol,
        @description : String = "",
        @required : Bool = false,
        @default : String? = nil,
        @type : Symbol = :string,
      )
      end
    end
  end
end
