require "../element"
require "../buffer"
require "../../style/color"

module Opal
  module UI
    enum SplitDirection
      Horizontal
      Vertical

      def self.from(val : SplitDirection | Symbol | String) : SplitDirection
        return val if val.is_a?(SplitDirection)
        case val.to_s.downcase
        when "vertical", "vert", "v", "col", "column"
          Vertical
        else
          Horizontal
        end
      end
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
      property min_first_size : Int32?
      property max_first_size : Int32?
      property separator : Char
      property separator_fg : Color
      property focused_pane : Symbol
      property? show_separator : Bool

      def initialize(
        @first : Element? = nil,
        @second : Element? = nil,
        direction : SplitDirection | Symbol | String = SplitDirection::Horizontal,
        @ratio : Float64? = 0.5,
        @first_size : Int32? = nil,
        @second_size : Int32? = nil,
        @min_first_size : Int32? = nil,
        @max_first_size : Int32? = nil,
        separator : Char? = nil,
        separator_fg : Color | Symbol | String = Color.none,
        focused_pane : Symbol = :first,
        @show_separator : Bool = true,
      )
        @direction = SplitDirection.from(direction)
        @separator = separator || (@direction == SplitDirection::Horizontal ? '│' : '─')
        @separator_fg = Color.from(separator_fg)
        @focused_pane = normalize_focus(focused_pane)
      end

      def self.horizontal(
        first : Element? = nil,
        second : Element? = nil,
        ratio : Float64? = 0.5,
        first_width : Int32? = nil,
        second_width : Int32? = nil,
        min_first_width : Int32? = nil,
        max_first_width : Int32? = nil,
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
          min_first_size: min_first_width,
          max_first_size: max_first_width,
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
        min_first_height : Int32? = nil,
        max_first_height : Int32? = nil,
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
          min_first_size: min_first_height,
          max_first_size: max_first_height,
          separator: separator,
          separator_fg: separator_fg,
          focused_pane: focused_pane,
          show_separator: show_separator
        )
      end

      # Toggles active focus between `:first` and `:second` pane.
      def toggle_focus : Symbol
        @focused_pane = (@focused_pane == :first ? :second : :first)
      end

      def focus_first : Nil
        @focused_pane = :first
      end

      def focus_second : Nil
        @focused_pane = :second
      end

      # Adjusts split ratio by `delta`, clamped within `[min_ratio, max_ratio]`.
      def adjust_ratio(delta : Float64, min_ratio : Float64 = 0.1, max_ratio : Float64 = 0.9) : Float64
        current = @ratio || 0.5
        updated = (current + delta).clamp(min_ratio, max_ratio)
        @ratio = updated
        updated
      end

      private def normalize_focus(pane : Symbol) : Symbol
        case pane
        when :second, :right, :bottom
          :second
        else
          :first
        end
      end

      private def resolve_first_extent(avail : Int32) : Int32
        raw = if fs = @first_size
                fs.clamp(0, avail)
              elsif ss = @second_size
                avail - ss.clamp(0, avail)
              else
                r = (@ratio || 0.5).clamp(0.0, 1.0)
                (avail * r).round.to_i.clamp(0, avail)
              end
        if min_s = @min_first_size
          raw = Math.max(raw, min_s.clamp(0, avail))
        end
        if max_s = @max_first_size
          raw = Math.min(raw, max_s.clamp(0, avail))
        end
        raw.clamp(0, avail)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if @direction == SplitDirection::Horizontal
          sep_w = @show_separator ? 1 : 0
          avail = Math.max(0, available_w - sep_w)
          w1 = resolve_first_extent(avail)
          w2 = avail - w1
          s1_w, s1_h = @first.try(&.preferred_size(w1, available_h)) || {0, 0}
          s2_w, s2_h = @second.try(&.preferred_size(w2, available_h)) || {0, 0}
          needed_w = s1_w + s2_w
          if @first_size.nil? && @second_size.nil?
            r = (@ratio || 0.5).clamp(0.05, 0.95)
            by_first = (s1_w / r).ceil.to_i
            by_second = (s2_w / (1.0 - r)).ceil.to_i
            needed_w = Math.max(needed_w, Math.max(by_first, by_second))
          end
          {Math.min(available_w, needed_w + sep_w), Math.max(s1_h, s2_h)}
        else
          sep_h = @show_separator ? 1 : 0
          avail = Math.max(0, available_h - sep_h)
          h1 = resolve_first_extent(avail)
          h2 = avail - h1
          s1_w, s1_h = @first.try(&.preferred_size(available_w, h1)) || {0, 0}
          s2_w, s2_h = @second.try(&.preferred_size(available_w, h2)) || {0, 0}
          needed_h = s1_h + s2_h
          if @first_size.nil? && @second_size.nil?
            r = (@ratio || 0.5).clamp(0.05, 0.95)
            by_first = (s1_h / r).ceil.to_i
            by_second = (s2_h / (1.0 - r)).ceil.to_i
            needed_h = Math.max(needed_h, Math.max(by_first, by_second))
          end
          {Math.max(s1_w, s2_w), Math.min(available_h, needed_h + sep_h)}
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

        w1 = resolve_first_extent(avail_w)
        w2 = avail_w - w1

        # Render first pane
        if (el1 = @first) && w1 > 0
          buffer.with_clip(x, y, w1, height) do
            el1.render(buffer, x, y, w1, height)
          end
        end

        # Render vertical separator
        if @show_separator && sep_w > 0
          sep_x = x + w1
          (0...height).each do |sy|
            buffer.put_char(sep_x, y + sy, @separator, fg: @separator_fg)
          end
        end

        # Render second pane
        if (el2 = @second) && w2 > 0
          pane2_x = x + w1 + sep_w
          buffer.with_clip(pane2_x, y, w2, height) do
            el2.render(buffer, pane2_x, y, w2, height)
          end
        end
      end

      private def render_vertical(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        sep_h = @show_separator ? 1 : 0
        avail_h = Math.max(0, height - sep_h)

        h1 = resolve_first_extent(avail_h)
        h2 = avail_h - h1

        # Render first pane
        if (el1 = @first) && h1 > 0
          buffer.with_clip(x, y, width, h1) do
            el1.render(buffer, x, y, width, h1)
          end
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
          pane2_y = y + h1 + sep_h
          buffer.with_clip(x, pane2_y, width, h2) do
            el2.render(buffer, x, pane2_y, width, h2)
          end
        end
      end
    end
  end
end
