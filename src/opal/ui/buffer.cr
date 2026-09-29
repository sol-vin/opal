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
        cell = Cell.new(
          char: char,
          fg: fg,
          bg: bg,
          bold: bold,
          dim: dim,
          italic: italic,
          underline: underline,
          reverse: reverse
        )
        set(x, y, cell)
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

      def to_s(io : IO) : Nil
        (0...@height).each do |y|
          (0...@width).each do |x|
            io << get(x, y).char
          end
          io.puts unless y == @height - 1
        end
      end
    end
  end
end
