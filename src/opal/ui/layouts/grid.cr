require "../element"
require "../control"
require "../buffer"

module Opal
  module UI
    struct GridTrack
      enum Kind
        Fixed
        Fraction
        Auto
      end

      getter kind : Kind
      getter value : Float64

      def initialize(@kind : Kind, @value : Float64 = 1.0)
      end

      def self.fixed(px : Int32) : GridTrack
        new(Kind::Fixed, px.to_f)
      end

      def self.fr(ratio : Float64 = 1.0) : GridTrack
        new(Kind::Fraction, ratio)
      end

      def self.auto : GridTrack
        new(Kind::Auto, 0.0)
      end
    end

    struct GridItem
      getter element : Element
      getter col : Int32
      getter row : Int32
      getter col_span : Int32
      getter row_span : Int32

      def initialize(
        @element : Element,
        @col : Int32,
        @row : Int32,
        @col_span : Int32 = 1,
        @row_span : Int32 = 1,
      )
      end
    end

    # Modern 2D CSS-style Grid container inspired by Python Textual's Grid layout.
    # Distributes cells across rows and columns using fractional (fr) units,
    # fixed widths, spans, and gutters.
    class GridContainer < Control
      property columns : Array(GridTrack)
      property rows : Array(GridTrack)
      property gutter_x : Int32
      property gutter_y : Int32
      getter items : Array(GridItem)

      def children : Array(Element)
        @items.map(&.element)
      end

      def initialize(
        columns : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        rows : Array(GridTrack | Int32 | Float64 | String) = [GridTrack.fr(1.0)],
        @gutter_x : Int32 = 1,
        @gutter_y : Int32 = 0,
      )
        super()
        @columns = parse_tracks(columns)
        @rows = parse_tracks(rows)
        @items = [] of GridItem
      end

      private def parse_tracks(tracks : Array(GridTrack | Int32 | Float64 | String)) : Array(GridTrack)
        tracks.map do |t|
          case t
          when GridTrack then t
          when Int32     then GridTrack.fixed(t)
          when Float64   then GridTrack.fr(t)
          when String
            if t.ends_with?("fr")
              val = t.rchop("fr").to_f? || 1.0
              GridTrack.fr(val)
            elsif t == "auto"
              GridTrack.auto
            else
              px = t.to_i? || 10
              GridTrack.fixed(px)
            end
          else
            GridTrack.fr(1.0)
          end
        end
      end

      # Adds child element to specific grid coordinate with optional spans
      def add(element : Element, col : Int32, row : Int32, col_span : Int32 = 1, row_span : Int32 = 1) : self
        @items << GridItem.new(element, col, row, col_span, row_span)
        self
      end

      # Adds child placing it automatically in the next open cell
      def add(element : Element) : self
        col_count = Math.max(1, @columns.size)
        idx = @items.size
        col = idx % col_count
        row = idx // col_count
        add(element, col, row)
      end

      # Computes pixel column widths given available width
      def compute_col_widths(available_w : Int32) : Array(Int32)
        count = @columns.size
        return [] of Int32 if count == 0

        total_gap = (count - 1) * @gutter_x
        remaining_w = Math.max(0, available_w - total_gap)

        widths = Array(Int32).new(count, 0)
        fixed_sum = 0
        total_fr = 0.0

        @columns.each_with_index do |t, idx|
          case t.kind
          when GridTrack::Kind::Fixed
            w = Math.min(remaining_w, t.value.to_i)
            widths[idx] = w
            fixed_sum += w
          when GridTrack::Kind::Fraction
            total_fr += t.value
          when GridTrack::Kind::Auto
            widths[idx] = 10
            fixed_sum += 10
          end
        end

        fr_space = Math.max(0, remaining_w - fixed_sum)
        if total_fr > 0.0
          @columns.each_with_index do |t, idx|
            if t.kind.fraction?
              w = ((t.value / total_fr) * fr_space).floor.to_i
              widths[idx] = w
            end
          end
        end

        widths
      end

      # Computes pixel row heights given available height
      def compute_row_heights(available_h : Int32) : Array(Int32)
        count = @rows.size
        return [] of Int32 if count == 0

        total_gap = (count - 1) * @gutter_y
        remaining_h = Math.max(0, available_h - total_gap)

        heights = Array(Int32).new(count, 0)
        fixed_sum = 0
        total_fr = 0.0

        @rows.each_with_index do |t, idx|
          case t.kind
          when GridTrack::Kind::Fixed
            h = Math.min(remaining_h, t.value.to_i)
            heights[idx] = h
            fixed_sum += h
          when GridTrack::Kind::Fraction
            total_fr += t.value
          when GridTrack::Kind::Auto
            heights[idx] = 1
            fixed_sum += 1
          end
        end

        fr_space = Math.max(0, remaining_h - fixed_sum)
        if total_fr > 0.0
          @rows.each_with_index do |t, idx|
            if t.kind.fraction?
              h = ((t.value / total_fr) * fr_space).floor.to_i
              heights[idx] = h
            end
          end
        end

        heights
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        @items.each do |it|
          if (el = it.element).is_a?(Control) && el.focused?
            return true if el.handle_key(event)
          end
        end
        @items.each do |it|
          if (el = it.element).is_a?(Control)
            return true if el.handle_key(event)
          end
        end
        false
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        @items.each do |it|
          if (el = it.element).is_a?(Control)
            return true if el.handle_mouse(event)
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @items.empty?

        col_w = compute_col_widths(width)
        row_h = compute_row_heights(height)

        return if col_w.empty? || row_h.empty?

        # Compute column start X offsets
        col_x = Array(Int32).new(col_w.size, 0)
        acc_x = x
        col_w.each_with_index do |w, i|
          col_x[i] = acc_x
          acc_x += w + @gutter_x
        end

        # Compute row start Y offsets
        row_y = Array(Int32).new(row_h.size, 0)
        acc_y = y
        row_h.each_with_index do |h, i|
          row_y[i] = acc_y
          acc_y += h + @gutter_y
        end

        @items.each do |item|
          c_idx = item.col.clamp(0, col_w.size - 1)
          r_idx = item.row.clamp(0, row_h.size - 1)

          cx = col_x[c_idx]
          cy = row_y[r_idx]

          # Span widths
          cw = 0
          (0...item.col_span).each do |span_i|
            idx = c_idx + span_i
            break if idx >= col_w.size
            cw += col_w[idx] + (span_i > 0 ? @gutter_x : 0)
          end

          # Span heights
          ch = 0
          (0...item.row_span).each do |span_i|
            idx = r_idx + span_i
            break if idx >= row_h.size
            ch += row_h[idx] + (span_i > 0 ? @gutter_y : 0)
          end

          next if cw <= 0 || ch <= 0

          buffer.with_clip(cx, cy, cw, ch) do
            item.element.render(buffer, cx, cy, cw, ch)
          end
        end
      end
    end
  end
end
