module Opal
  # Border glyph definitions for boxes, cards, windows, and tables.
  # Supports standard line styles, character swaps, and repeating multi-character
  # pattern borders (e.g. "-+-+-+", "=~=~=", or custom corners).
  struct Border
    getter top : String
    getter bottom : String
    getter left : String
    getter right : String
    getter top_left : String
    getter top_right : String
    getter bottom_left : String
    getter bottom_right : String

    def initialize(
      @top : String,
      @bottom : String,
      @left : String,
      @right : String,
      @top_left : String,
      @top_right : String,
      @bottom_left : String,
      @bottom_right : String,
    )
    end

    def self.none : Border
      new("", "", "", "", "", "", "", "")
    end

    def self.rounded : Border
      new(
        top: "─", bottom: "─", left: "│", right: "│",
        top_left: "╭", top_right: "╮",
        bottom_left: "╰", bottom_right: "╯"
      )
    end

    def self.single : Border
      new(
        top: "─", bottom: "─", left: "│", right: "│",
        top_left: "┌", top_right: "┐",
        bottom_left: "└", bottom_right: "┘"
      )
    end

    def self.double : Border
      new(
        top: "═", bottom: "═", left: "║", right: "║",
        top_left: "╔", top_right: "╗",
        bottom_left: "╚", bottom_right: "╝"
      )
    end

    def self.thick : Border
      new(
        top: "━", bottom: "━", left: "┃", right: "┃",
        top_left: "┏", top_right: "┓",
        bottom_left: "┗", bottom_right: "┛"
      )
    end

    def self.ascii : Border
      new(
        top: "-", bottom: "-", left: "|", right: "|",
        top_left: "+", top_right: "+",
        bottom_left: "+", bottom_right: "+"
      )
    end

    def self.hidden : Border
      new(
        top: " ", bottom: " ", left: " ", right: " ",
        top_left: " ", top_right: " ",
        bottom_left: " ", bottom_right: " "
      )
    end

    # Creates a custom repeating pattern border (e.g. top: "-+", left: "|", corners: "+")
    def self.pattern(top : String, left : String = "|", corners : String = "+") : Border
      new(
        top: top,
        bottom: top,
        left: left,
        right: left,
        top_left: corners,
        top_right: corners,
        bottom_left: corners,
        bottom_right: corners
      )
    end

    # Creates a custom repeating pattern border with distinct horizontal, vertical, and corner symbols
    def self.pattern(
      top : String,
      bottom : String,
      left : String,
      right : String,
      corners : String,
    ) : Border
      new(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        top_left: corners,
        top_right: corners,
        bottom_left: corners,
        bottom_right: corners
      )
    end

    # Creates a custom pattern border with fully specified corners
    def self.pattern(
      top : String,
      bottom : String,
      left : String,
      right : String,
      top_left : String,
      top_right : String,
      bottom_left : String,
      bottom_right : String,
    ) : Border
      new(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        top_left: top_left,
        top_right: top_right,
        bottom_left: bottom_left,
        bottom_right: bottom_right
      )
    end

    def self.from(style : Symbol | Border | String) : Border
      return style if style.is_a?(Border)

      case style
      when :rounded               then rounded
      when :single, :normal       then single
      when :double                then double
      when :thick, :bold, :heavy  then thick
      when :ascii                 then ascii
      when :hidden                then hidden
      when String
        p = style.starts_with?("pattern:") ? style[8..] : style
        case p
        when "rounded"                 then rounded
        when "single", "normal"        then single
        when "double"                  then double
        when "thick", "bold", "heavy"  then thick
        when "ascii"                   then ascii
        when "hidden"                  then hidden
        else
          if p.size > 1
            pattern(p, left: "|", corners: "+")
          else
            ascii
          end
        end
      else
        none
      end
    end

    def active? : Bool
      !@top.empty? || !@left.empty?
    end

    # Generates a tiled horizontal string for the top edge of specified character length
    def top_segment(length : Int32) : String
      return "" if length <= 0
      return @top * length if @top.size <= 1
      chars = @top.chars
      String.build(length) do |sb|
        length.times { |i| sb << chars[i % chars.size] }
      end
    end

    # Generates a tiled horizontal string for the bottom edge of specified character length
    def bottom_segment(length : Int32) : String
      return "" if length <= 0
      return @bottom * length if @bottom.size <= 1
      chars = @bottom.chars
      String.build(length) do |sb|
        length.times { |i| sb << chars[i % chars.size] }
      end
    end

    # Returns the left border character for a given row offset within the height
    def left_char(offset : Int32) : Char
      return ' ' if @left.empty?
      chars = @left.chars
      chars[offset % chars.size]
    end

    # Returns the right border character for a given row offset within the height
    def right_char(offset : Int32) : Char
      return ' ' if @right.empty?
      chars = @right.chars
      chars[offset % chars.size]
    end

    # Returns a new border with selected pieces swapped
    def swap(
      top : String? = nil,
      bottom : String? = nil,
      left : String? = nil,
      right : String? = nil,
      corners : String? = nil,
      top_left : String? = nil,
      top_right : String? = nil,
      bottom_left : String? = nil,
      bottom_right : String? = nil,
    ) : Border
      tl = top_left || corners || @top_left
      tr = top_right || corners || @top_right
      bl = bottom_left || corners || @bottom_left
      br = bottom_right || corners || @bottom_right

      Border.new(
        top: top || @top,
        bottom: bottom || @bottom,
        left: left || @left,
        right: right || @right,
        top_left: tl,
        top_right: tr,
        bottom_left: bl,
        bottom_right: br
      )
    end
  end
end
