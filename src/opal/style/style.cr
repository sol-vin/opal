require "./color"
require "./border"
require "./visual_width"

module Opal
  # Fluent declarative styling engine inspired by Charm's Lipgloss.
  class Style
    property foreground : Color = Color.none
    property background : Color = Color.none
    property? bold : Bool = false
    property? faint : Bool = false
    property? italic : Bool = false
    property? underline : Bool = false
    property? blink : Bool = false
    property? reverse : Bool = false
    property? strikethrough : Bool = false

    property border : Border = Border.none
    property border_foreground : Color = Color.none
    property border_background : Color = Color.none

    property padding_top : Int32 = 0
    property padding_right : Int32 = 0
    property padding_bottom : Int32 = 0
    property padding_left : Int32 = 0

    property margin_top : Int32 = 0
    property margin_right : Int32 = 0
    property margin_bottom : Int32 = 0
    property margin_left : Int32 = 0

    property align : Symbol = :left
    property width : Int32? = nil
    property height : Int32? = nil

    def initialize
    end

    # Fluent modifiers
    def fg(color : Color | Symbol | String) : self
      @foreground = Color.from(color)
      self
    end

    def foreground(color : Color | Symbol | String) : self
      fg(color)
    end

    def bg(color : Color | Symbol | String) : self
      @background = Color.from(color)
      self
    end

    def background(color : Color | Symbol | String) : self
      bg(color)
    end

    def bold(val : Bool = true) : self
      @bold = val
      self
    end

    def faint(val : Bool = true) : self
      @faint = val
      self
    end

    def dim(val : Bool = true) : self
      faint(val)
    end

    def italic(val : Bool = true) : self
      @italic = val
      self
    end

    def underline(val : Bool = true) : self
      @underline = val
      self
    end

    def blink(val : Bool = true) : self
      @blink = val
      self
    end

    def reverse(val : Bool = true) : self
      @reverse = val
      self
    end

    def strikethrough(val : Bool = true) : self
      @strikethrough = val
      self
    end

    def border(style : Symbol | Border, fg : Color | Symbol | String = Color.none, bg : Color | Symbol | String = Color.none) : self
      @border = Border.from(style)
      @border_foreground = Color.from(fg)
      @border_background = Color.from(bg)
      self
    end

    def padding(all : Int32) : self
      @padding_top = @padding_right = @padding_bottom = @padding_left = all
      self
    end

    def padding(vertical : Int32, horizontal : Int32) : self
      @padding_top = @padding_bottom = vertical
      @padding_right = @padding_left = horizontal
      self
    end

    def padding(top : Int32, right : Int32, bottom : Int32, left : Int32) : self
      @padding_top = top
      @padding_right = right
      @padding_bottom = bottom
      @padding_left = left
      self
    end

    def margin(all : Int32) : self
      @margin_top = @margin_right = @margin_bottom = @margin_left = all
      self
    end

    def margin(vertical : Int32, horizontal : Int32) : self
      @margin_top = @margin_bottom = vertical
      @margin_right = @margin_left = horizontal
      self
    end

    def margin(top : Int32, right : Int32, bottom : Int32, left : Int32) : self
      @margin_top = top
      @margin_right = right
      @margin_bottom = bottom
      @margin_left = left
      self
    end

    def align(val : Symbol) : self
      @align = val
      self
    end

    def width(val : Int32) : self
      @width = val
      self
    end

    def height(val : Int32) : self
      @height = val
      self
    end

    # Renders text with all applied styling, padding, borders, and margins.
    def render(content : String) : String
      return "" if content.empty? && !@border.active? && @padding_top == 0 && @padding_bottom == 0

      lines = content.split('\n')

      # Calculate natural content width
      max_line_width = lines.map { |l| VisualWidth.width(l) }.max? || 0
      content_width = @width ? Math.max(@width.not_nil!, max_line_width) : max_line_width

      # Format each line with alignment and horizontal padding
      formatted_lines = lines.map do |line|
        cur_w = VisualWidth.width(line)
        diff = Math.max(0, content_width - cur_w)

        aligned_text = case @align
                       when :center
                         left_pad = diff // 2
                         right_pad = diff - left_pad
                         (" " * left_pad) + line + (" " * right_pad)
                       when :right
                         (" " * diff) + line
                       else # :left
                         line + (" " * diff)
                       end

        # Apply padding left and right
        padded_text = (" " * @padding_left) + aligned_text + (" " * @padding_right)

        # Apply inline styling
        apply_text_styling(padded_text)
      end

      # Total inner block width (including horizontal padding)
      inner_width = content_width + @padding_left + @padding_right

      # Vertical padding lines
      blank_line = apply_text_styling(" " * inner_width)
      top_padding = Array.new(@padding_top, blank_line)
      bottom_padding = Array.new(@padding_bottom, blank_line)

      all_body_lines = top_padding + formatted_lines + bottom_padding

      # Handle vertical height constraint if specified
      if h = @height
        while all_body_lines.size < h
          all_body_lines << blank_line
        end
        if all_body_lines.size > h
          all_body_lines = all_body_lines[0...h]
        end
      end

      # Apply border if active
      result_lines = if @border.active?
                       wrap_with_border(all_body_lines, inner_width)
                     else
                       all_body_lines
                     end

      # Apply margins
      apply_margins(result_lines)
    end

    private def apply_text_styling(text : String) : String
      codes = [] of String
      codes << "1" if @bold
      codes << "2" if @faint
      codes << "3" if @italic
      codes << "4" if @underline
      codes << "5" if @blink
      codes << "7" if @reverse
      codes << "9" if @strikethrough

      prefix = IO::Memory.new
      prefix << "\e[" + codes.join(';') + "m" unless codes.empty?
      prefix << @foreground.fg_escape
      prefix << @background.bg_escape

      p_str = prefix.to_s
      return text if p_str.empty?

      p_str + text + "\e[0m"
    end

    private def border_style(glyph : String) : String
      return glyph if glyph.empty?
      fg = @border_foreground.fg_escape
      bg = @border_background.bg_escape
      return glyph if fg.empty? && bg.empty?
      "#{fg}#{bg}#{glyph}\e[0m"
    end

    private def wrap_with_border(body_lines : Array(String), inner_width : Int32) : Array(String)
      out = [] of String

      # Top border
      if !@border.top.empty? || !@border.top_left.empty?
        top_str = border_style(@border.top_left) +
                  border_style(@border.top * inner_width) +
                  border_style(@border.top_right)
        out << top_str
      end

      # Body with left/right borders
      body_lines.each do |line|
        left_str = border_style(@border.left)
        right_str = border_style(@border.right)
        out << "#{left_str}#{line}#{right_str}"
      end

      # Bottom border
      if !@border.bottom.empty? || !@border.bottom_left.empty?
        bot_str = border_style(@border.bottom_left) +
                  border_style(@border.bottom * inner_width) +
                  border_style(@border.bottom_right)
        out << bot_str
      end

      out
    end

    private def apply_margins(lines : Array(String)) : String
      left_margin = " " * @margin_left
      margined_lines = lines.map { |l| "#{left_margin}#{l}" }

      io = IO::Memory.new
      @margin_top.times { io.puts }
      margined_lines.each do |line|
        io.puts line
      end
      @margin_bottom.times { io.puts }

      io.to_s.chomp
    end
  end
end
