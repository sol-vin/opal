require "../ui/buffer"
require "../style/color"
require "../style/border"

module Opal
  module Graphics
    # 2D geometry rasterization primitives for terminal buffers.
    # Provides Bresenham line drawing, rectangles, midpoint circles/ellipses with
    # aspect ratio compensation, drop shadows, and scanline-filled triangles.
    module Primitives2D
      # Draws a line between (x0, y0) and (x1, y1) using integer Bresenham algorithm.
      def self.draw_line(
        buffer : UI::Buffer,
        x0 : Int32,
        y0 : Int32,
        x1 : Int32,
        y1 : Int32,
        char : Char = '─',
        fg : Color = Color.none,
        bg : Color = Color.none,
        style : Symbol = :solid,
      ) : Nil
        # Fast path for horizontal line
        if y0 == y1
          draw_hline(buffer, Math.min(x0, x1), y0, (x1 - x0).abs + 1, char, fg, bg, style)
          return
        end

        # Fast path for vertical line
        if x0 == x1
          vchar = (char == '─') ? '│' : char
          draw_vline(buffer, x0, Math.min(y0, y1), (y1 - y0).abs + 1, vchar, fg, bg, style)
          return
        end

        dx = (x1 - x0).abs
        dy = -(y1 - y0).abs
        sx = x0 < x1 ? 1 : -1
        sy = y0 < y1 ? 1 : -1
        err = dx + dy

        cur_x = x0
        cur_y = y0
        step_count = 0

        loop do
          should_draw = case style
                        when :dashed
                          (step_count % 3) != 2
                        when :dotted
                          (step_count % 2) == 0
                        else
                          true
                        end

          if should_draw
            # Determine appropriate directional line character if using default
            plot_char = if char == '─'
                          if (cur_x - x1).abs > (cur_y - y1).abs * 2
                            '─'
                          elsif (cur_y - y1).abs > (cur_x - x1).abs * 2
                            '│'
                          elsif (sx > 0 && sy > 0) || (sx < 0 && sy < 0)
                            '\\'
                          else
                            '/'
                          end
                        else
                          char
                        end
            buffer.put_char(cur_x, cur_y, plot_char, fg: fg, bg: bg)
          end

          break if cur_x == x1 && cur_y == y1

          e2 = 2 * err
          if e2 >= dy
            err += dy
            cur_x += sx
          end
          if e2 <= dx
            err += dx
            cur_y += sy
          end
          step_count += 1
        end
      end

      # Fast horizontal line
      def self.draw_hline(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        length : Int32,
        char : Char = '─',
        fg : Color = Color.none,
        bg : Color = Color.none,
        style : Symbol = :solid,
      ) : Nil
        return if length <= 0
        (0...length).each do |offset|
          should_draw = case style
                        when :dashed
                          (offset % 3) != 2
                        when :dotted
                          (offset % 2) == 0
                        else
                          true
                        end
          if should_draw
            buffer.put_char(x + offset, y, char, fg: fg, bg: bg)
          end
        end
      end

      # Fast vertical line
      def self.draw_vline(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        length : Int32,
        char : Char = '│',
        fg : Color = Color.none,
        bg : Color = Color.none,
        style : Symbol = :solid,
      ) : Nil
        return if length <= 0
        (0...length).each do |offset|
          should_draw = case style
                        when :dashed
                          (offset % 3) != 2
                        when :dotted
                          (offset % 2) == 0
                        else
                          true
                        end
          if should_draw
            buffer.put_char(x, y + offset, char, fg: fg, bg: bg)
          end
        end
      end

      # Draws an outlined rectangle using border characters
      def self.draw_rect(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        border : Symbol | Border = :rounded,
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        return if width < 2 || height < 2
        b = case border
            when Border         then border
            when :double        then Border.double
            when :heavy, :thick then Border.thick
            when :ascii         then Border.ascii
            else                     Border.rounded
            end

        # Top border
        buffer.put_string(x, y, b.top_left, fg: fg, bg: bg)
        buffer.put_string(x + 1, y, b.top_segment(width - 2), fg: fg, bg: bg)
        buffer.put_string(x + width - 1, y, b.top_right, fg: fg, bg: bg)

        # Side borders
        (1...(height - 1)).each do |row|
          buffer.put_char(x, y + row, b.left_char(row - 1), fg: fg, bg: bg)
          buffer.put_char(x + width - 1, y + row, b.right_char(row - 1), fg: fg, bg: bg)
        end

        # Bottom border
        buffer.put_string(x, y + height - 1, b.bottom_left, fg: fg, bg: bg)
        buffer.put_string(x + 1, y + height - 1, b.bottom_segment(width - 2), fg: fg, bg: bg)
        buffer.put_string(x + width - 1, y + height - 1, b.bottom_right, fg: fg, bg: bg)
      end

      # Fills a rectangle with character and styling
      def self.fill_rect(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        char : Char = ' ',
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        buffer.fill(x, y, width, height, char, fg: fg, bg: bg)
      end

      # Draws a shaded drop shadow along the right and bottom sides of a box
      def self.draw_shadow(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        shadow_char : Char = '░',
        fg : Color = Color.rgb(40, 40, 40),
      ) : Nil
        # Right shadow
        (1..height).each do |row|
          buffer.put_char(x + width, y + row, shadow_char, fg: fg)
          buffer.put_char(x + width + 1, y + row, shadow_char, fg: fg)
        end

        # Bottom shadow
        (2..(width + 1)).each do |col|
          buffer.put_char(x + col, y + height, shadow_char, fg: fg)
        end
      end

      # Draws an ellipse using the midpoint algorithm
      def self.draw_ellipse(
        buffer : UI::Buffer,
        cx : Int32,
        cy : Int32,
        rx : Int32,
        ry : Int32,
        char : Char = '●',
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        return if rx <= 0 || ry <= 0

        # Bresenham ellipse
        x = 0
        y = ry
        d1 = ((ry * ry) - (rx * rx * ry) + (0.25 * rx * rx)).to_i
        dx = 2 * ry * ry * x
        dy = 2 * rx * rx * y

        # Region 1
        while dx < dy
          plot_ellipse_points(buffer, cx, cy, x, y, char, fg, bg)
          if d1 < 0
            x += 1
            dx += 2 * ry * ry
            d1 += dx + (ry * ry)
          else
            x += 1
            y -= 1
            dx += 2 * ry * ry
            dy -= 2 * rx * rx
            d1 += dx - dy + (ry * ry)
          end
        end

        # Region 2
        d2 = ((ry * ry) * ((x + 0.5) * (x + 0.5)) + (rx * rx) * ((y - 1) * (y - 1)) - (rx * rx * ry * ry)).to_i
        while y >= 0
          plot_ellipse_points(buffer, cx, cy, x, y, char, fg, bg)
          if d2 > 0
            y -= 1
            dy -= 2 * rx * rx
            d2 += (rx * rx) - dy
          else
            y -= 1
            x += 1
            dx += 2 * ry * ry
            dy -= 2 * rx * rx
            d2 += dx - dy + (rx * rx)
          end
        end
      end

      # Draws a circle using midpoint algorithm with terminal aspect ratio compensation
      def self.draw_circle(
        buffer : UI::Buffer,
        cx : Int32,
        cy : Int32,
        radius : Int32,
        char : Char = '●',
        fg : Color = Color.none,
        bg : Color = Color.none,
        aspect_ratio : Float64 = 2.0,
      ) : Nil
        return if radius <= 0
        rx = (radius.to_f * aspect_ratio).round.to_i
        draw_ellipse(buffer, cx, cy, rx, radius, char: char, fg: fg, bg: bg)
      end

      # Fills a circle/ellipse
      def self.fill_circle(
        buffer : UI::Buffer,
        cx : Int32,
        cy : Int32,
        radius : Int32,
        char : Char = '█',
        fg : Color = Color.none,
        bg : Color = Color.none,
        aspect_ratio : Float64 = 2.0,
      ) : Nil
        return if radius <= 0
        rx = (radius.to_f * aspect_ratio).round.to_i
        ry = radius

        (-ry..ry).each do |dy|
          # Solve for x: (x/rx)^2 + (dy/ry)^2 <= 1
          y_norm = dy.to_f / ry.to_f
          if (1.0 - y_norm * y_norm) >= 0.0
            x_span = (rx.to_f * Math.sqrt(1.0 - y_norm * y_norm)).round.to_i
            draw_hline(buffer, cx - x_span, cy + dy, (2 * x_span) + 1, char, fg, bg)
          end
        end
      end

      private def self.plot_ellipse_points(
        buffer : UI::Buffer,
        cx : Int32,
        cy : Int32,
        x : Int32,
        y : Int32,
        char : Char,
        fg : Color,
        bg : Color,
      ) : Nil
        buffer.put_char(cx + x, cy + y, char, fg: fg, bg: bg)
        buffer.put_char(cx - x, cy + y, char, fg: fg, bg: bg)
        buffer.put_char(cx + x, cy - y, char, fg: fg, bg: bg)
        buffer.put_char(cx - x, cy - y, char, fg: fg, bg: bg)
      end

      # Draws a wireframe triangle
      def self.draw_triangle(
        buffer : UI::Buffer,
        x0 : Int32, y0 : Int32,
        x1 : Int32, y1 : Int32,
        x2 : Int32, y2 : Int32,
        char : Char = '*',
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        draw_line(buffer, x0, y0, x1, y1, char, fg, bg)
        draw_line(buffer, x1, y1, x2, y2, char, fg, bg)
        draw_line(buffer, x2, y2, x0, y0, char, fg, bg)
      end

      # Scanline-fills a triangle
      def self.fill_triangle(
        buffer : UI::Buffer,
        x0 : Int32, y0 : Int32,
        x1 : Int32, y1 : Int32,
        x2 : Int32, y2 : Int32,
        char : Char = '█',
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        # Sort vertices by y ascending
        pts = [{x0, y0}, {x1, y1}, {x2, y2}].sort_by(&.[1])
        p0, p1, p2 = pts[0], pts[1], pts[2]

        total_height = p2[1] - p0[1]
        return if total_height == 0

        (0..total_height).each do |i|
          second_half = i > (p1[1] - p0[1]) || (p1[1] == p0[1])
          segment_height = second_half ? (p2[1] - p1[1]) : (p1[1] - p0[1])
          next if segment_height == 0

          alpha = i.to_f / total_height.to_f
          beta = (i - (second_half ? (p1[1] - p0[1]) : 0)).to_f / segment_height.to_f

          ax = (p0[0].to_f + (p2[0] - p0[0]).to_f * alpha).round.to_i
          bx = second_half ? (p1[0].to_f + (p2[0] - p1[0]).to_f * beta).round.to_i : (p0[0].to_f + (p1[0] - p0[0]).to_f * beta).round.to_i

          min_x = Math.min(ax, bx)
          max_x = Math.max(ax, bx)
          draw_hline(buffer, min_x, p0[1] + i, max_x - min_x + 1, char, fg, bg)
        end
      end

      # Convenience aliases for intuitive graphics scripting
      def self.line(buffer : UI::Buffer, x0 : Int32, y0 : Int32, x1 : Int32, y1 : Int32, char : Char = '─', fg : Color = Color.none, bg : Color = Color.none, style : Symbol = :solid) : Nil
        draw_line(buffer, x0, y0, x1, y1, char: char, fg: fg, bg: bg, style: style)
      end

      def self.circle(buffer : UI::Buffer, cx : Int32, cy : Int32, radius : Int32, char : Char = '●', fg : Color = Color.none, bg : Color = Color.none, aspect_ratio : Float64 = 2.0) : Nil
        draw_circle(buffer, cx, cy, radius, char: char, fg: fg, bg: bg, aspect_ratio: aspect_ratio)
      end

      def self.ellipse(buffer : UI::Buffer, cx : Int32, cy : Int32, rx : Int32, ry : Int32, char : Char = '●', fg : Color = Color.none, bg : Color = Color.none) : Nil
        draw_ellipse(buffer, cx, cy, rx, ry, char: char, fg: fg, bg: bg)
      end

      def self.rect(buffer : UI::Buffer, x : Int32, y : Int32, width : Int32, height : Int32, border : Symbol | Border = :rounded, fg : Color = Color.none, bg : Color = Color.none) : Nil
        draw_rect(buffer, x, y, width, height, border: border, fg: fg, bg: bg)
      end

      def self.rect_with_shadow(
        buffer : UI::Buffer,
        x : Int32,
        y : Int32,
        width : Int32,
        height : Int32,
        border : Symbol | Border = :rounded,
        border_fg : Color = Color.none,
        shadow_char : Char = '░',
        title : String? = nil,
      ) : Nil
        draw_rect(buffer, x, y, width, height, border: border, fg: border_fg)
        draw_shadow(buffer, x, y, width, height, shadow_char: shadow_char)
        if title
          buffer.put_string(x + 2, y, " #{title} ", fg: border_fg, bold: true)
        end
      end
    end
  end
end
