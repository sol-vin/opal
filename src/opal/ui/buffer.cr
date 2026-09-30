require "./cell"
require "../style/visual_width"

module Opal
  module UI
    # In-memory 2D grid of screen cells representing a terminal frame.
    class Buffer
      getter width : Int32
      getter height : Int32
      getter cells : Array(Cell)

      def initialize(@width : Int32, @height : Int32)
        @cells = Array(Cell).new(@width * @height, Cell.empty)
      end

      def in_bounds?(x : Int32, y : Int32) : Bool
        x >= 0 && x < @width && y >= 0 && y < @height
      end

      def get(x : Int32, y : Int32) : Cell
        return Cell.empty unless in_bounds?(x, y)
        @cells[y * @width + x]
      end

      def set(x : Int32, y : Int32, cell : Cell) : Nil
        return unless in_bounds?(x, y)
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
      ) : Nil
        return unless in_bounds?(x, y)

        # If overwriting a continuation cell, clear the preceding wide character cell
        if x > 0 && get(x, y).continuation?
          set(x - 1, y, Cell.empty)
        end

        # If this cell previously had a wide character, clear its continuation cell
        if x + 1 < @width && get(x + 1, y).continuation?
          set(x + 1, y, Cell.empty)
        end

        cell = Cell.new(
          char: char,
          fg: fg,
          bg: bg,
          bold: bold,
          dim: dim,
          italic: italic,
          underline: underline,
          reverse: reverse,
          continuation: false
        )
        set(x, y, cell)

        cw = VisualWidth.char_width(char)
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
      ) : Int32
        cur_x = x
        clean_text = VisualWidth.strip_ansi(text)

        clean_text.each_char do |ch|
          break if cur_x >= @width
          if mw = max_width
            break if (cur_x - x) >= mw
          end

          cw = VisualWidth.char_width(ch)
          if cw > 0
            put_char(
              cur_x, y, ch,
              fg: fg, bg: bg,
              bold: bold, dim: dim,
              italic: italic, underline: underline,
              reverse: reverse
            )
            cur_x += cw
          end
        end

        cur_x - x
      end

      def fill(x : Int32, y : Int32, w : Int32, h : Int32, cell : Cell = Cell.empty) : Nil
        (y...(y + h)).each do |cur_y|
          (x...(x + w)).each do |cur_x|
            set(cur_x, cur_y, cell)
          end
        end
      end

      def clear : Nil
        @cells.fill(Cell.empty)
      end

      def clone : Buffer
        buf = Buffer.new(@width, @height)
        @cells.each_with_index do |cell, idx|
          buf.cells[idx] = cell
        end
        buf
      end

      # Blits (copies) another buffer onto this buffer at the given coordinates.
      # If ignore_spaces is true, empty cells without background do not overwrite existing cells.
      def blit(src : Buffer, dst_x : Int32, dst_y : Int32, ignore_spaces : Bool = false) : Nil
        (0...src.height).each do |sy|
          (0...src.width).each do |sx|
            cell = src.get(sx, sy)
            next if ignore_spaces && cell.char == ' ' && cell.bg.type == Color::Type::None
            set(dst_x + sx, dst_y + sy, cell)
          end
        end
      end

      # Applies dimming attribute to all cells within the given rectangle.
      def dim_rect(x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        (y...(y + h)).each do |cur_y|
          (x...(x + w)).each do |cur_x|
            cell = get(cur_x, cur_y)
            set(cur_x, cur_y, Cell.new(
              char: cell.char,
              fg: cell.fg,
              bg: cell.bg,
              bold: false,
              dim: true,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
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
