require "./cell"
require "./rect"
require "../style/visual_width"

module Opal
  module UI
    # In-memory 2D grid of screen cells representing a terminal frame.
    class Buffer
      getter width : Int32
      getter height : Int32
      getter cells : Array(Cell)
      property clip_rect : Rect? = nil

      def initialize(@width : Int32, @height : Int32)
        @cells = Array(Cell).new(@width * @height, Cell.empty)
      end

      def in_bounds?(x : Int32, y : Int32) : Bool
        x >= 0 && x < @width && y >= 0 && y < @height
      end

      # Returns true if the coordinate is within the buffer bounds and the active clip rect (if any).
      def in_clip?(x : Int32, y : Int32) : Bool
        return false unless in_bounds?(x, y)
        if cr = @clip_rect
          cr.in_bounds?(x, y)
        else
          true
        end
      end

      # Executes a block with an active clipping rectangle.
      # If a clip rectangle is already active, computes their intersection.
      def with_clip(x : Int32, y : Int32, w : Int32, h : Int32, &block)
        new_rect = Rect.new(x, y, Math.max(0, w), Math.max(0, h))
        if old_clip = @clip_rect
          new_rect = old_clip.intersection(new_rect)
        end

        prev = @clip_rect
        @clip_rect = new_rect
        begin
          yield
        ensure
          @clip_rect = prev
        end
      end

      def get(x : Int32, y : Int32) : Cell
        return Cell.empty unless in_bounds?(x, y)
        @cells[y * @width + x]
      end

      def set(x : Int32, y : Int32, cell : Cell) : Nil
        return unless in_clip?(x, y)
        @cells[y * @width + x] = cell
      end

      def put_char(
        x : Int32,
        y : Int32,
        char : Char,
        fg : Color = Color.none,
        bg : Color = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
        reverse : Bool = false,
        keep_bg : Bool = false,
      ) : Nil
        return unless in_clip?(x, y)

        # If overwriting a continuation cell, clear the preceding wide character cell
        if x > 0 && in_bounds?(x - 1, y) && get(x, y).continuation?
          set(x - 1, y, Cell.empty)
        end

        # If this cell previously had a wide character, clear its continuation cell
        if x + 1 < @width && in_bounds?(x + 1, y) && get(x + 1, y).continuation?
          set(x + 1, y, Cell.empty)
        end

        cw = VisualWidth.char_width(char)
        if cw == 2
          if x + 1 >= @width || !in_clip?(x + 1, y)
            # Cannot fit wide character or continuation is clipped; replace with space to avoid line wrap
            char = ' '
            cw = 1
          else
            # If x + 1 was previously a wide character, clear its old continuation at x + 2
            if x + 2 < @width && get(x + 2, y).continuation?
              set(x + 2, y, Cell.empty)
            end
          end
        end

        actual_bg = (keep_bg && bg.type == Color::Type::None) ? get(x, y).bg : bg

        cell = Cell.new(
          char: char,
          fg: fg,
          bg: actual_bg,
          bold: bold,
          dim: dim,
          italic: italic,
          underline: underline,
          reverse: reverse,
          continuation: false
        )
        set(x, y, cell)

        if cw == 2 && x + 1 < @width
          set(x + 1, y, Cell.continuation)
        end
      end

      def put_string(
        x : Int32,
        y : Int32,
        text : String,
        fg : Color = Color.none,
        bg : Color = Color.none,
        bold : Bool = false,
        dim : Bool = false,
        italic : Bool = false,
        underline : Bool = false,
        reverse : Bool = false,
        max_width : Int32? = nil,
        keep_bg : Bool = false,
      ) : Int32
        return 0 if y < 0 || y >= @height
        if cr = @clip_rect
          return 0 if y < cr.y || y >= cr.bottom
        end
        cur_x = x
        clean_text = VisualWidth.strip_ansi(text)

        clean_text.each_char do |ch|
          cw = VisualWidth.char_width(ch)
          next if cw <= 0

          break if cur_x >= @width
          if cr = @clip_rect
            break if cur_x + cw > cr.right
          end
          if mw = max_width
            break if (cur_x - x) + cw > mw
          end

          if cur_x >= 0 && (cr.nil? || cur_x >= cr.not_nil!.x)
            put_char(
              cur_x, y, ch,
              fg: fg, bg: bg,
              bold: bold, dim: dim,
              italic: italic, underline: underline,
              reverse: reverse,
              keep_bg: keep_bg
            )
          end
          cur_x += cw
        end

        Math.max(0, cur_x - x)
      end

      # Writes string and pads remaining columns up to `width` with spaces, ensuring clean erasure
      def put_line(
        x : Int32,
        y : Int32,
        text : String,
        width : Int32,
        fg : Color = Color.none,
        bg : Color = Color.none,
        bold : Bool = false,
        dim : Bool = false,
      ) : Nil
        return if y < 0 || y >= @height
        if cr = @clip_rect
          return if y < cr.y || y >= cr.bottom
        end
        written_w = put_string(x, y, text, fg: fg, bg: bg, bold: bold, dim: dim, max_width: width)
        if written_w < width
          (written_w...width).each do |pad_x|
            px = x + pad_x
            break if px >= @width
            if cr = @clip_rect
              break if px >= cr.right
            end
            if px >= 0 && (cr.nil? || px >= cr.not_nil!.x)
              put_char(px, y, ' ', fg: fg, bg: bg)
            end
          end
        end
      end

      def fill(x : Int32, y : Int32, w : Int32, h : Int32, cell : Cell = Cell.empty) : Nil
        return if w <= 0 || h <= 0
        (y...(y + h)).each do |cur_y|
          next if cur_y < 0 || cur_y >= @height
          if cr = @clip_rect
            next if cur_y < cr.y || cur_y >= cr.bottom
          end
          # Clear boundary wide characters to prevent slicing
          if x > 0 && in_bounds?(x, cur_y) && get(x, cur_y).continuation?
            set(x - 1, cur_y, Cell.empty)
          end
          if (x + w) < @width && in_bounds?(x + w, cur_y) && get(x + w, cur_y).continuation?
            set(x + w, cur_y, Cell.empty)
          end

          (x...(x + w)).each do |cur_x|
            next if cur_x < 0 || cur_x >= @width
            if cr = @clip_rect
              next if cur_x < cr.x || cur_x >= cr.right
            end
            set(cur_x, cur_y, cell)
          end
        end
      end

      def fill(
        x : Int32,
        y : Int32,
        w : Int32,
        h : Int32,
        char : Char,
        fg : Color = Color.none,
        bg : Color = Color.none,
      ) : Nil
        fill(x, y, w, h, Cell.new(char: char, fg: fg, bg: bg))
      end

      def clear : Nil
        @cells.fill(Cell.empty)
      end

      # In-place copies all cells and dimensions from another buffer without reallocating
      def copy_from(other : Buffer) : Nil
        if @width != other.width || @height != other.height
          @width = other.width
          @height = other.height
          @cells = Array(Cell).new(@width * @height, Cell.empty)
        end
        other.cells.to_unsafe.copy_to(@cells.to_unsafe, @cells.size)
      end

      def clone : Buffer
        buf = Buffer.new(@width, @height)
        @cells.to_unsafe.copy_to(buf.cells.to_unsafe, @cells.size)
        buf
      end

      # Blits (copies) another buffer onto this buffer at the given coordinates.
      # If ignore_spaces is true, empty cells without background do not overwrite existing cells.
      def blit(src : Buffer, dst_x : Int32, dst_y : Int32, ignore_spaces : Bool = false) : Nil
        (0...src.height).each do |sy|
          target_y = dst_y + sy
          next if target_y < 0 || target_y >= @height
          if cr = @clip_rect
            next if target_y < cr.y || target_y >= cr.bottom
          end
          (0...src.width).each do |sx|
            target_x = dst_x + sx
            next if target_x < 0 || target_x >= @width
            if cr = @clip_rect
              next if target_x < cr.x || target_x >= cr.right
            end
            cell = src.get(sx, sy)
            next if ignore_spaces && cell.char == ' ' && cell.bg.type == Color::Type::None
            set(target_x, target_y, cell)
          end
        end
      end

      # Applies dimming attribute to all cells within the given rectangle.
      def dim_rect(x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        return if w <= 0 || h <= 0
        min_y = Math.max(0, y)
        max_y = Math.min(@height, y + h)
        if cr = @clip_rect
          min_y = Math.max(min_y, cr.y)
          max_y = Math.min(max_y, cr.bottom)
        end
        return if min_y >= max_y

        min_x = Math.max(0, x)
        max_x = Math.min(@width, x + w)
        if cr = @clip_rect
          min_x = Math.max(min_x, cr.x)
          max_x = Math.min(max_x, cr.right)
        end
        return if min_x >= max_x

        (min_y...max_y).each do |cur_y|
          (min_x...max_x).each do |cur_x|
            cell = get(cur_x, cur_y)
            set(cur_x, cur_y, Cell.new(
              char: cell.char,
              fg: cell.fg,
              bg: cell.bg,
              bold: false,
              dim: true,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?,
              continuation: cell.continuation?
            ))
          end
        end
      end

      # Dims the entire buffer to create a backdrop effect.
      def dim_all : Nil
        dim_rect(0, 0, @width, @height)
      end

      # Renders the buffer content to a string, optionally including ANSI color and style sequences.
      def render_to_string(with_ansi : Bool = true) : String
        String.build do |io|
          (0...@height).each do |y|
            last_fg = Color.none
            last_bg = Color.none
            last_bold = false
            last_dim = false
            last_italic = false
            last_underline = false

            row_content = String.build do |row_io|
              (0...@width).each do |x|
                cell = get(x, y)
                next if cell.continuation?

                if with_ansi
                  if cell.bold? != last_bold ||
                     cell.dim? != last_dim ||
                     cell.italic? != last_italic ||
                     cell.underline? != last_underline ||
                     cell.fg != last_fg ||
                     cell.bg != last_bg
                    row_io << "\e[0m"
                    last_bold = cell.bold?
                    last_dim = cell.dim?
                    last_italic = cell.italic?
                    last_underline = cell.underline?
                    last_fg = cell.fg
                    last_bg = cell.bg

                    codes = [] of String
                    codes << "1" if last_bold
                    codes << "2" if last_dim
                    codes << "3" if last_italic
                    codes << "4" if last_underline
                    row_io << "\e[" + codes.join(';') + "m" unless codes.empty?
                    row_io << last_fg.fg_escape
                    row_io << last_bg.bg_escape
                  end
                end
                row_io << cell.char
              end
              row_io << "\e[0m" if with_ansi
            end
            io.puts row_content.rstrip
          end
        end
      end

      def to_s(io : IO) : Nil
        (0...@height).each do |y|
          (0...@width).each do |x|
            cell = get(x, y)
            next if cell.continuation?
            io << cell.char
          end
          io.puts unless y == @height - 1
        end
      end

      # Applies a custom text shader block to this buffer (or a specific region)
      def shade(
        region : Shader::Rect? = nil,
        time : Float64 = 0.0,
        frame : UInt64 = 0_u64,
        &block : Shader::ShaderContext -> Nil
      ) : self
        pass = Shader::FragmentPass.new(region, &block)
        apply_shader(pass, time, frame)
      end

      # Applies a shader pass to this buffer
      def apply_shader(pass : Shader::Pass, time : Float64 = 0.0, frame : UInt64 = 0_u64) : self
        dst = clone
        pass.apply(self, dst, time, frame)
        (0...@height).each do |y|
          (0...@width).each do |x|
            set(x, y, dst.get(x, y))
          end
        end
        self
      end
    end
  end
end
