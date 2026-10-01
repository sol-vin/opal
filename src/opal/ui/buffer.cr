require "./cell"
require "./rect"
require "./mask"
require "../style/visual_width"

module Opal
  module UI
    enum BlitMode
      Replace
      Blend
      Alpha
      IgnoreSpaces
      Mask
    end

    # In-memory 2D grid of screen cells representing a terminal frame.
    class Buffer
      getter width : Int32
      getter height : Int32
      getter cells : Array(Cell)
      property clip_rect : Rect? = nil

      # Active mask for masked rendering operations
      property active_mask : MaskMap? = nil
      property mask_offset_x : Int32 = 0
      property mask_offset_y : Int32 = 0
      property mask_feather : Bool = true

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

      # Clip execution using a Rect struct
      def with_clip(rect : Rect, &)
        with_clip(rect.x, rect.y, rect.width, rect.height) { yield }
      end

      # Executes a block with an active scissor clipping rectangle.
      def with_scissor(rect : Rect, &)
        with_clip(rect.x, rect.y, rect.width, rect.height) { yield }
      end

      def with_scissor(x : Int32, y : Int32, w : Int32, h : Int32, &)
        with_clip(x, y, w, h) { yield }
      end

      # Executes a block with an active mask map.
      def with_mask(mask : MaskMap, offset_x : Int32 = 0, offset_y : Int32 = 0, feather : Bool = true, &)
        prev_mask = @active_mask
        prev_ox = @mask_offset_x
        prev_oy = @mask_offset_y
        prev_feather = @mask_feather

        @active_mask = mask
        @mask_offset_x = offset_x
        @mask_offset_y = offset_y
        @mask_feather = feather
        begin
          yield
        ensure
          @active_mask = prev_mask
          @mask_offset_x = prev_ox
          @mask_offset_y = prev_oy
          @mask_feather = prev_feather
        end
      end

      def get(x : Int32, y : Int32) : Cell
        return Cell.empty unless in_bounds?(x, y)
        @cells[y * @width + x]
      end

      def set(x : Int32, y : Int32, cell : Cell) : Nil
        return unless in_clip?(x, y)
        if mask = @active_mask
          mx = x - @mask_offset_x
          my = y - @mask_offset_y
          weight = mask.get(mx, my)
          return if weight <= 0.001
          if weight < 0.999 && @mask_feather
            cell = blend_cell_mask(cell, weight)
          end
        end
        @cells[y * @width + x] = cell
      end

      private def blend_cell_mask(cell : Cell, weight : Float64) : Cell
        if cell.char == ' '
          dither = MaskMap.dither_char(weight)
          Cell.new(
            char: dither,
            fg: cell.fg.type == Color::Type::None ? Color.ansi(90) : cell.fg,
            bg: cell.bg,
            dim: true
          )
        elsif weight < 0.35
          Cell.new(char: '░', fg: cell.fg, bg: cell.bg, dim: true)
        elsif weight < 0.70
          Cell.new(char: '▒', fg: cell.fg, bg: cell.bg, dim: true)
        else
          Cell.new(
            char: cell.char,
            fg: cell.fg,
            bg: cell.bg,
            bold: cell.bold?,
            dim: true,
            italic: cell.italic?,
            underline: cell.underline?,
            reverse: cell.reverse?
          )
        end
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

      # Copies a subregion of this buffer into a new standalone Buffer.
      def copy(rect : Rect) : Buffer
        copy(rect.x, rect.y, rect.width, rect.height)
      end

      def copy(x : Int32, y : Int32, w : Int32, h : Int32) : Buffer
        rw = Math.max(0, w)
        rh = Math.max(0, h)
        sub = Buffer.new(rw, rh)
        (0...rh).each do |sy|
          src_y = y + sy
          next if src_y < 0 || src_y >= @height
          (0...rw).each do |sx|
            src_x = x + sx
            next if src_x < 0 || src_x >= @width
            sub.set(sx, sy, get(src_x, src_y))
          end
        end
        sub
      end

      # Alias for copy
      def crop(rect : Rect) : Buffer
        copy(rect)
      end

      def crop(x : Int32, y : Int32, w : Int32, h : Int32) : Buffer
        copy(x, y, w, h)
      end

      # Pastes another buffer onto this buffer with selectable BlitMode and optional alpha
      def paste(src : Buffer, dst_x : Int32, dst_y : Int32, mode : BlitMode = BlitMode::Replace, alpha : Float64 = 1.0) : Nil
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

            src_cell = src.get(sx, sy)
            case mode
            when BlitMode::Replace
              set(target_x, target_y, src_cell)
            when BlitMode::IgnoreSpaces
              next if src_cell.char == ' ' && src_cell.bg.type == Color::Type::None
              set(target_x, target_y, src_cell)
            when BlitMode::Blend, BlitMode::Alpha
              dst_cell = get(target_x, target_y)
              if src_cell.char == ' ' && src_cell.bg.type == Color::Type::None
                next
              end
              blended_fg = Color.lerp(dst_cell.fg, src_cell.fg, alpha)
              blended_bg = Color.lerp(dst_cell.bg, src_cell.bg, alpha)
              set(target_x, target_y, Cell.new(
                char: src_cell.char == ' ' ? dst_cell.char : src_cell.char,
                fg: blended_fg,
                bg: blended_bg,
                bold: src_cell.bold?,
                dim: src_cell.dim?,
                italic: src_cell.italic?,
                underline: src_cell.underline?,
                reverse: src_cell.reverse?
              ))
            when BlitMode::Mask
              if @active_mask
                set(target_x, target_y, src_cell)
              else
                next if src_cell.char == ' '
                set(target_x, target_y, src_cell)
              end
            end
          end
        end
      end

      # Inverts foreground and background colors in a rectangle
      def invert(rect : Rect) : Nil
        invert(rect.x, rect.y, rect.width, rect.height)
      end

      def invert(x : Int32, y : Int32, w : Int32, h : Int32) : Nil
        return if w <= 0 || h <= 0
        (y...(y + h)).each do |cur_y|
          next if cur_y < 0 || cur_y >= @height
          if cr = @clip_rect
            next if cur_y < cr.y || cur_y >= cr.bottom
          end
          (x...(x + w)).each do |cur_x|
            next if cur_x < 0 || cur_x >= @width
            if cr = @clip_rect
              next if cur_x < cr.x || cur_x >= cr.right
            end
            cell = get(cur_x, cur_y)
            set(cur_x, cur_y, Cell.new(
              char: cell.char,
              fg: cell.bg.type == Color::Type::None ? Color.white : cell.bg,
              bg: cell.fg.type == Color::Type::None ? Color.black : cell.fg,
              bold: cell.bold?,
              dim: cell.dim?,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: !cell.reverse?,
              continuation: cell.continuation?
            ))
          end
        end
      end

      # Fills a rectangle with a specified cell
      def fill_rect(rect : Rect, cell : Cell = Cell.empty) : Nil
        fill(rect.x, rect.y, rect.width, rect.height, cell)
      end

      def fill_rect(x : Int32, y : Int32, w : Int32, h : Int32, cell : Cell = Cell.empty) : Nil
        fill(x, y, w, h, cell)
      end

      # Shifts cells within a rect by dx and dy, filling exposed regions with fill_char
      def scroll_rect(rect : Rect, dx : Int32, dy : Int32, fill_char : Char = ' ') : Nil
        rx = Math.max(0, rect.x)
        ry = Math.max(0, rect.y)
        rw = Math.min(@width - rx, rect.width)
        rh = Math.min(@height - ry, rect.height)
        return if rw <= 0 || rh <= 0

        snapshot = copy(rx, ry, rw, rh)
        fill(rx, ry, rw, rh, Cell.new(char: fill_char))

        with_clip(rx, ry, rw, rh) do
          (0...rh).each do |sy|
            dst_y = ry + sy + dy
            next if dst_y < ry || dst_y >= (ry + rh)
            (0...rw).each do |sx|
              dst_x = rx + sx + dx
              next if dst_x < rx || dst_x >= (rx + rw)
              set(dst_x, dst_y, snapshot.get(sx, sy))
            end
          end
        end
      end

      # Transforms: Rotate 90 degrees clockwise or counterclockwise
      def rotate_90(clockwise : Bool = true) : Buffer
        rot = Buffer.new(@height, @width)
        (0...@height).each do |y|
          (0...@width).each do |x|
            cell = get(x, y)
            trans_char = Buffer.rotate_glyph(cell.char, clockwise ? 1 : 3)
            new_cell = Cell.new(
              char: trans_char,
              fg: cell.fg,
              bg: cell.bg,
              bold: cell.bold?,
              dim: cell.dim?,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
            )
            if clockwise
              rot.set(@height - 1 - y, x, new_cell)
            else
              rot.set(y, @width - 1 - x, new_cell)
            end
          end
        end
        rot
      end

      def rotate_180 : Buffer
        rot = Buffer.new(@width, @height)
        (0...@height).each do |y|
          (0...@width).each do |x|
            cell = get(x, y)
            trans_char = Buffer.rotate_glyph(cell.char, 2)
            rot.set(@width - 1 - x, @height - 1 - y, Cell.new(
              char: trans_char,
              fg: cell.fg,
              bg: cell.bg,
              bold: cell.bold?,
              dim: cell.dim?,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
            ))
          end
        end
        rot
      end

      def flip_h : Buffer
        buf = Buffer.new(@width, @height)
        (0...@height).each do |y|
          (0...@width).each do |x|
            cell = get(x, y)
            buf.set(@width - 1 - x, y, Cell.new(
              char: Buffer.flip_h_glyph(cell.char),
              fg: cell.fg,
              bg: cell.bg,
              bold: cell.bold?,
              dim: cell.dim?,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
            ))
          end
        end
        buf
      end

      def flip_v : Buffer
        buf = Buffer.new(@width, @height)
        (0...@height).each do |y|
          (0...@width).each do |x|
            cell = get(x, y)
            buf.set(x, @height - 1 - y, Cell.new(
              char: Buffer.flip_v_glyph(cell.char),
              fg: cell.fg,
              bg: cell.bg,
              bold: cell.bold?,
              dim: cell.dim?,
              italic: cell.italic?,
              underline: cell.underline?,
              reverse: cell.reverse?
            ))
          end
        end
        buf
      end

      # Box-drawing glyph transposition helpers
      def self.rotate_glyph(ch : Char, turns : Int32) : Char
        return ch if turns % 4 == 0
        cur = ch
        (turns % 4).times do
          cur = case cur
                when '─' then '│'
                when '│' then '─'
                when '═' then '║'
                when '║' then '═'
                when '┌' then '┐'
                when '┐' then '┘'
                when '┘' then '└'
                when '└' then '┌'
                when '╔' then '╗'
                when '╗' then '╝'
                when '╝' then '╚'
                when '╚' then '╔'
                when '╭' then '╮'
                when '╮' then '╯'
                when '╯' then '╰'
                when '╰' then '╭'
                when '▲' then '▶'
                when '▶' then '▼'
                when '▼' then '◀'
                when '◀' then '▲'
                when '↑' then '→'
                when '→' then '↓'
                when '↓' then '←'
                when '←' then '↑'
                else          cur
                end
        end
        cur
      end

      def self.flip_h_glyph(ch : Char) : Char
        case ch
        when '┌' then '┐'
        when '┐' then '┌'
        when '└' then '┘'
        when '┘' then '└'
        when '╔' then '╗'
        when '╗' then '╔'
        when '╚' then '╝'
        when '╝' then '╚'
        when '╭' then '╮'
        when '╮' then '╭'
        when '╰' then '╯'
        when '╯' then '╰'
        when '◀' then '▶'
        when '▶' then '◀'
        when '←' then '→'
        when '→' then '←'
        when '/' then '\\'
        when '\\' then '/'
        when '(' then ')'
        when ')' then '('
        when '[' then ']'
        when ']' then '['
        when '{' then '}'
        when '}' then '{'
        when '<' then '>'
        when '>' then '<'
        else          ch
        end
      end

      def self.flip_v_glyph(ch : Char) : Char
        case ch
        when '┌' then '└'
        when '└' then '┌'
        when '┐' then '┘'
        when '┘' then '┐'
        when '╔' then '╚'
        when '╚' then '╔'
        when '╗' then '╝'
        when '╝' then '╗'
        when '╭' then '╰'
        when '╰' then '╭'
        when '╮' then '╯'
        when '╯' then '╮'
        when '▲' then '▼'
        when '▼' then '▲'
        when '↑' then '↓'
        when '↓' then '↑'
        else          ch
        end
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
