require "../element"
require "../rect"
require "../buffer"
require "../../style/border"
require "../../style/color"

module Opal
  module UI
    enum LayoutDirection
      Vertical
      Horizontal
      Stack
      Flow
    end

    enum OverflowPolicy
      Hidden
      Scroll
      Visible
    end

    # Flexible container and grouping element supporting directional child layouts,
    # background fills, borders, titles, and strict overflow clipping policies.
    class Group < Element
      property title : String? = nil
      property direction : LayoutDirection = LayoutDirection::Vertical
      property overflow : OverflowPolicy = OverflowPolicy::Hidden
      property border : Border = Border.none
      property border_color : Color = Color.none
      property title_color : Color = Color.hex("#38ef7d")
      property background : Color = Color.none
      property padding : Int32 = 0
      property scroll_x : Int32 = 0
      property scroll_y : Int32 = 0
      property elements : Array(Element) = [] of Element

      def initialize(
        @title : String? = nil,
        @direction : LayoutDirection = LayoutDirection::Vertical,
        @overflow : OverflowPolicy = OverflowPolicy::Hidden,
        @border : Border = Border.none,
        @padding : Int32 = 0
      )
        super()
      end

      def add(el : Element) : self
        @elements << el
        self
      end

      def <<(el : Element) : self
        add(el)
      end

      def children : Array(Element)
        @elements
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        # Optional background fill
        if @background.type != Color::Type::None
          buffer.fill(x, y, width, height, Cell.new(bg: @background))
        end

        inner_x = x
        inner_y = y
        inner_w = width
        inner_h = height

        # Draw border if enabled
        if !@border.top.empty? || !@border.left.empty?
          draw_border(buffer, x, y, width, height)
          inner_x += 1
          inner_y += 1
          inner_w = Math.max(0, inner_w - 2)
          inner_h = Math.max(0, inner_h - 2)
        end

        # Apply padding
        inner_x += @padding
        inner_y += @padding
        inner_w = Math.max(0, inner_w - (@padding * 2))
        inner_h = Math.max(0, inner_h - (@padding * 2))

        return if inner_w <= 0 || inner_h <= 0

        # Overflow handling
        case @overflow
        when OverflowPolicy::Hidden, OverflowPolicy::Scroll
          buffer.with_scissor(Rect.new(inner_x, inner_y, inner_w, inner_h)) do
            render_children(buffer, inner_x - @scroll_x, inner_y - @scroll_y, inner_w, inner_h)
          end
          if @overflow == OverflowPolicy::Scroll && @elements.size > inner_h
            # Draw simple scroll track indicator on right edge
            (0...inner_h).each do |si|
              buffer.put_char(inner_x + inner_w - 1, inner_y + si, '│', fg: Color.ansi(240))
            end
          end
        when OverflowPolicy::Visible
          render_children(buffer, inner_x - @scroll_x, inner_y - @scroll_y, inner_w, inner_h)
        end
      end

      private def draw_border(buffer : Buffer, bx : Int32, by : Int32, bw : Int32, bh : Int32) : Nil
        fg = @border_color

        # Corners
        buffer.put_string(bx, by, @border.top_left, fg: fg)
        buffer.put_string(bx + bw - @border.top_right.size, by, @border.top_right, fg: fg)
        buffer.put_string(bx, by + bh - 1, @border.bottom_left, fg: fg)
        buffer.put_string(bx + bw - @border.bottom_right.size, by + bh - 1, @border.bottom_right, fg: fg)

        # Top and bottom horizontal lines
        (1...bw - 1).each do |xi|
          buffer.put_string(bx + xi, by, @border.top, fg: fg)
          buffer.put_string(bx + xi, by + bh - 1, @border.bottom, fg: fg)
        end

        # Left and right vertical lines
        (1...bh - 1).each do |yi|
          buffer.put_string(bx, by + yi, @border.left, fg: fg)
          buffer.put_string(bx + bw - 1, by + yi, @border.right, fg: fg)
        end

        # Title
        if t = @title
          clean_title = " #{t} "
          if clean_title.size < bw - 4
            buffer.put_string(bx + 2, by, clean_title, fg: @title_color, bold: true)
          end
        end
      end

      private def render_children(buffer : Buffer, ox : Int32, oy : Int32, max_w : Int32, max_h : Int32) : Nil
        case @direction
        when LayoutDirection::Vertical
          cur_y = oy
          @elements.each do |el|
            pw, ph = el.preferred_size(max_w, max_h)
            ch_w = Math.min(pw, max_w)
            ch_h = Math.min(ph, max_h)
            el.render(buffer, ox, cur_y, ch_w, ch_h)
            cur_y += ch_h
          end
        when LayoutDirection::Horizontal
          cur_x = ox
          col_w = @elements.empty? ? max_w : (max_w // @elements.size)
          @elements.each do |el|
            el.render(buffer, cur_x, oy, col_w, max_h)
            cur_x += col_w
          end
        when LayoutDirection::Stack
          @elements.each do |el|
            el.render(buffer, ox, oy, max_w, max_h)
          end
        when LayoutDirection::Flow
          cur_x = ox
          cur_y = oy
          row_h = 1
          @elements.each do |el|
            pw, ph = el.preferred_size(max_w, max_h)
            if cur_x + pw > ox + max_w && cur_x > ox
              cur_x = ox
              cur_y += row_h
              row_h = 1
            end
            el.render(buffer, cur_x, cur_y, pw, ph)
            cur_x += pw + 1
            row_h = Math.max(row_h, ph)
          end
        end
      end
    end

    alias Container = Group
  end
end
