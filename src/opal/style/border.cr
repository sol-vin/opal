module Opal
  # Border glyph definitions for boxes, cards, and tables.
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

    def self.from(style : Symbol | Border) : Border
      return style if style.is_a?(Border)

      case style
      when :rounded         then rounded
      when :single, :normal then single
      when :double          then double
      when :thick, :bold    then thick
      when :ascii           then ascii
      when :hidden          then hidden
      else                       none
      end
    end

    def active? : Bool
      !@top.empty? || !@left.empty?
    end
  end
end
