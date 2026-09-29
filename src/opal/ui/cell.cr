require "../style/color"

module Opal
  module UI
    # Represents a single character cell on the terminal screen grid with color and styling attributes.
    struct Cell
      property char : Char
      property fg : Color
      property bg : Color
      property? bold : Bool
      property? dim : Bool
      property? italic : Bool
      property? underline : Bool
      property? reverse : Bool

      def initialize(
        @char : Char = ' ',
        @fg : Color = Color.none,
        @bg : Color = Color.none,
        @bold : Bool = false,
        @dim : Bool = false,
        @italic : Bool = false,
        @underline : Bool = false,
        @reverse : Bool = false,
      )
      end

      def self.empty : Cell
        new(' ', Color.none, Color.none)
      end

      def ==(other : Cell) : Bool
        @char == other.char &&
          @fg == other.fg &&
          @bg == other.bg &&
          @bold == other.bold? &&
          @dim == other.dim? &&
          @italic == other.italic? &&
          @underline == other.underline? &&
          @reverse == other.reverse?
      end
    end
  end
end
