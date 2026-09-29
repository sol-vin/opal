require "../element"
require "../buffer"
require "../../style/color"

module Opal
  module UI
    enum SplitDirection
      Horizontal
      Vertical
    end

    # Multi-pane split view container supporting horizontal (side-by-side)
    # and vertical (stacked) layouts with configurable proportions and borders.
    class SplitView < Element
      property direction : SplitDirection
      property first : Element?
      property second : Element?
      property ratio : Float64?
      property first_size : Int32?
      property second_size : Int32?
      property separator : Char
      property separator_fg : Color
      property focused_pane : Symbol
      property? show_separator : Bool

      def initialize(
        @first : Element? = nil,
        @second : Element? = nil,
        @direction : SplitDirection = SplitDirection::Horizontal,
        @ratio : Float64? = 0.5,
        @first_size : Int32? = nil,
        @second_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        @focused_pane : Symbol = :first,
        @show_separator : Bool = true,
      )
        @separator = separator || (@direction == SplitDirection::Horizontal ? '│' : '─')
        @separator_fg = Color.from(separator_fg)
      end

      def self.horizontal(
        first : Element? = nil,
        second : Element? = nil,
        ratio : Float64? = 0.5,
        first_width : Int32? = nil,
        second_width : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
      ) : SplitView
        new(
          first: first,
          second: second,
          direction: SplitDirection::Horizontal,
          ratio: ratio,
          first_size: first_width,
          second_size: second_width,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
      end

      def self.vertical(
        first : Element? = nil,
        second : Element? = nil,
        ratio : Float64? = 0.5,
        first_height : Int32? = nil,
        second_height : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        show_separator : Bool = true,
      ) : SplitView
        new(
          first: first,
          second: second,
          direction: SplitDirection::Vertical,
          ratio: ratio,
          first_size: first_height,
          second_size: second_height,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if @direction == SplitDirection::Horizontal
          sep_w = @show_separator ? 1 : 0
          avail = Math.max(0, available_w - sep_w)
          w1 = (avail * (@ratio || 0.5)).round.to_i
          w2 = avail - w1
          s1_w, s1_h = @first.try(&.preferred_size(w1, available_h)) || {0, 0}
          s2_w, s2_h = @second.try(&.preferred_size(w2, available_h)) || {0, 0}
          {Math.min(available_w, s1_w + s2_w + sep_w), Math.max(s1_h, s2_h)}
        else
          sep_h = @show_separator ? 1 : 0
          avail = Math.max(0, available_h - sep_h)
          h1 = (avail * (@ratio || 0.5)).round.to_i
          h2 = avail - h1
          s1_w, s1_h = @first.try(&.preferred_size(available_w, h1)) || {0, 0}
          s2_w, s2_h = @second.try(&.preferred_size(available_w, h2)) || {0, 0}
          {Math.max(s1_w, s2_w), Math.min(available_h, s1_h + s2_h + sep_h)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        if @direction == SplitDirection::Horizontal
          render_horizontal(buffer, x, y, width, height)
        else
          render_vertical(buffer, x, y, width, height)
        end
      end

      private def render_horizontal(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        sep_w = @show_separator ? 1 : 0
        avail_w = Math.max(0, width - sep_w)

        w1 = if fs = @first_size
               fs.clamp(0, avail_w)
             elsif ss = @second_size
               avail_w - ss.clamp(0, avail_w)
             else
               r = (@ratio || 0.5).clamp(0.0, 1.0)
               (avail_w * r).round.to_i.clamp(0, avail_w)
             end
        w2 = avail_w - w1

        # Render first pane into sub-buffer and blit
        if (el1 = @first) && w1 > 0
          sub_buf1 = Buffer.new(w1, height)
          el1.render(sub_buf1, 0, 0, w1, height)
          buffer.blit(sub_buf1, x, y)
        end

        # Render vertical separator
        if @show_separator && sep_w > 0
          sep_x = x + w1
          (0...height).each do |sy|
            buffer.put_char(sep_x, y + sy, @separator, fg: @separator_fg)
          end
        end

        # Render second pane into sub-buffer and blit
        if (el2 = @second) && w2 > 0
          sub_buf2 = Buffer.new(w2, height)
          el2.render(sub_buf2, 0, 0, w2, height)
          buffer.blit(sub_buf2, x + w1 + sep_w, y)
        end
      end

      private def render_vertical(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        sep_h = @show_separator ? 1 : 0
        avail_h = Math.max(0, height - sep_h)

        h1 = if fs = @first_size
               fs.clamp(0, avail_h)
             elsif ss = @second_size
               avail_h - ss.clamp(0, avail_h)
             else
               r = (@ratio || 0.5).clamp(0.0, 1.0)
               (avail_h * r).round.to_i.clamp(0, avail_h)
             end
        h2 = avail_h - h1

        # Render first pane
        if (el1 = @first) && h1 > 0
          sub_buf1 = Buffer.new(width, h1)
          el1.render(sub_buf1, 0, 0, width, h1)
          buffer.blit(sub_buf1, x, y)
        end

        # Render horizontal separator
        if @show_separator && sep_h > 0
          sep_y = y + h1
          (0...width).each do |sx|
            buffer.put_char(x + sx, sep_y, @separator, fg: @separator_fg)
          end
        end

        # Render second pane
        if (el2 = @second) && h2 > 0
          sub_buf2 = Buffer.new(width, h2)
          el2.render(sub_buf2, 0, 0, width, h2)
          buffer.blit(sub_buf2, x, y + h1 + sep_h)
        end
      end
    end
  end
end
