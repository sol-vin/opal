module Opal
  module Graphics
    # Visual preset styles for character grids.
    enum GridStylePreset
      Solid
      Heavy
      Double
      Dashed
      Dotted
      Dots
      Crosses
      Ascii
      Blocks
      MathQuad

      def to_s(io : IO) : Nil
        case self
        in Solid    then io << "solid"
        in Heavy    then io << "heavy"
        in Double   then io << "double"
        in Dashed   then io << "dashed"
        in Dotted   then io << "dotted"
        in Dots     then io << "dots"
        in Crosses  then io << "crosses"
        in Ascii    then io << "ascii"
        in Blocks   then io << "blocks"
        in MathQuad then io << "math_quad"
        end
      end

      def self.parse?(str : String | Symbol) : GridStylePreset?
        case str.to_s.downcase.strip
        when "solid"                 then Solid
        when "heavy"                 then Heavy
        when "double"                then Double
        when "dashed"                then Dashed
        when "dotted"                then Dotted
        when "dots"                  then Dots
        when "crosses", "cross"      then Crosses
        when "ascii"                 then Ascii
        when "blocks", "block"       then Blocks
        when "math_quad", "mathquad" then MathQuad
        else                              nil
        end
      end
    end

    # Glyphs defining the visual appearance of horizontal lines,
    # vertical lines, intersections, and empty spaces on a character grid.
    struct GridGlyphs
      getter horizontal : Char
      getter vertical : Char
      getter intersection : Char
      getter empty : Char

      def initialize(
        @horizontal : Char = '─',
        @vertical : Char = '│',
        @intersection : Char = '┼',
        @empty : Char = ' ',
      )
      end

      def self.solid : GridGlyphs
        new(horizontal: '─', vertical: '│', intersection: '┼', empty: ' ')
      end

      def self.heavy : GridGlyphs
        new(horizontal: '━', vertical: '┃', intersection: '╋', empty: ' ')
      end

      def self.double : GridGlyphs
        new(horizontal: '═', vertical: '║', intersection: '╬', empty: ' ')
      end

      def self.dashed : GridGlyphs
        new(horizontal: '┄', vertical: '┆', intersection: '┼', empty: ' ')
      end

      def self.dotted : GridGlyphs
        new(horizontal: '┈', vertical: '┊', intersection: '·', empty: ' ')
      end

      def self.dots : GridGlyphs
        new(horizontal: ' ', vertical: ' ', intersection: '·', empty: ' ')
      end

      def self.crosses : GridGlyphs
        new(horizontal: ' ', vertical: ' ', intersection: '+', empty: ' ')
      end

      def self.ascii : GridGlyphs
        new(horizontal: '-', vertical: '|', intersection: '+', empty: ' ')
      end

      def self.blocks : GridGlyphs
        new(horizontal: '▀', vertical: '▌', intersection: '█', empty: ' ')
      end

      def self.math_quad : GridGlyphs
        new(horizontal: '─', vertical: '│', intersection: '·', empty: ' ')
      end

      def self.preset(style : GridStylePreset | Symbol | String) : GridGlyphs
        p = style.is_a?(GridStylePreset) ? style : (GridStylePreset.parse?(style) || GridStylePreset::Solid)
        case p
        in GridStylePreset::Solid    then solid
        in GridStylePreset::Heavy    then heavy
        in GridStylePreset::Double   then double
        in GridStylePreset::Dashed   then dashed
        in GridStylePreset::Dotted   then dotted
        in GridStylePreset::Dots     then dots
        in GridStylePreset::Crosses  then crosses
        in GridStylePreset::Ascii    then ascii
        in GridStylePreset::Blocks   then blocks
        in GridStylePreset::MathQuad then math_quad
        end
      end
    end
  end
end
