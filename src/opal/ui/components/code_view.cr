require "string_scanner"
require "../control"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Code and disassembly viewing element with line numbers,
    # syntax highlighting, cursor indicator, and vertical scrolling.
    class CodeView < Control
      property code : String
      property language : Symbol # :asm, :c, :crystal, :plain
      property start_line : Int32
      property highlighted_line : Int32?
      property scroll_offset : Int32
      property? show_line_numbers : Bool
      property gutter_fg : Color?
      property cursor_fg : Color?
      property cursor_indicator : String?
      property? scrollable : Bool = true
      property? auto_scroll : Bool = false
      property scroll_speed : Float64 = 1.0
      @scroll_accumulator : Float64 = 0.0

      # Cached layout coordinates for mouse interaction
      @last_x : Int32 = 0
      @last_y : Int32 = 0
      @last_w : Int32 = 0
      @last_h : Int32 = 0

      def initialize(
        @code : String = "",
        language : Symbol | String = :plain,
        @start_line : Int32 = 1,
        @highlighted_line : Int32? = nil,
        @scroll_offset : Int32 = 0,
        @show_line_numbers : Bool = true,
        gutter_fg : Color | Symbol | String | Nil = nil,
        cursor_fg : Color | Symbol | String | Nil = nil,
        @cursor_indicator : String? = nil,
        @scrollable : Bool = true,
        @auto_scroll : Bool = false,
        @scroll_speed : Float64 = 1.0,
      )
        super()
        @language = language.is_a?(Symbol) ? language : (
          case language.downcase
          when "crystal", "cr"       then :crystal
          when "ruby", "rb"          then :ruby
          when "python", "py"        then :python
          when "javascript", "js"    then :javascript
          when "json"                then :json
          when "bash", "sh", "shell" then :bash
          when "sql"                 then :sql
          when "html", "xml"         then :html
          when "css"                 then :css
          when "markdown", "md"      then :markdown
          when "diff", "patch"       then :diff
          when "yaml", "yml"         then :yaml
          else                            :plain
          end
        )
        @gutter_fg = gutter_fg ? Color.from(gutter_fg) : nil
        @cursor_fg = cursor_fg ? Color.from(cursor_fg) : nil
      end

      def lines : Array(String)
        @code.split('\n')
      end

      def tick(dt : Float64 = 0.0166) : Nil
        return unless @auto_scroll
        @scroll_accumulator += dt * @scroll_speed * 2.0
        if @scroll_accumulator >= 1.0
          steps = @scroll_accumulator.to_i
          @scroll_accumulator -= steps
          max_scroll = Math.max(0, lines.size - (@last_h > 0 ? @last_h : 10))
          if @scroll_offset >= max_scroll
            @scroll_offset = 0
          else
            @scroll_offset = Math.min(max_scroll, @scroll_offset + steps)
          end
        end
      end

      def scroll_up(count : Int32 = 1) : Nil
        return unless @scrollable
        @scroll_offset = Math.max(0, @scroll_offset - count)
      end

      def scroll_down(count : Int32 = 1) : Nil
        return unless @scrollable
        max_scroll = Math.max(0, lines.size - 1)
        @scroll_offset = Math.min(max_scroll, @scroll_offset + count)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        all_lines = lines
        gutter_w = @show_line_numbers ? calculate_gutter_width(all_lines.size) : 0
        max_line_w = all_lines.map { |l| VisualWidth.width(l) }.max? || 0
        total_w = gutter_w + max_line_w
        {Math.min(available_w, total_w), Math.min(available_h, all_lines.size)}
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false unless @scrollable
        case event.name
        when "up", "k"
          scroll_up(1)
          true
        when "down", "j"
          scroll_down(1)
          true
        when "page_up", "pageup"
          scroll_up(@last_h > 0 ? @last_h : 10)
          true
        when "page_down", "pagedown"
          scroll_down(@last_h > 0 ? @last_h : 10)
          true
        when "home"
          @scroll_offset = 0
          true
        when "end"
          @scroll_offset = Math.max(0, lines.size - 1)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          return false unless @scrollable
          scroll_up(2)
          return true
        when Terminal::MouseButton::WheelDown
          return false unless @scrollable
          scroll_down(2)
          return true
        end

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          if event.x >= @last_x && event.x < @last_x + @last_w &&
             event.y >= @last_y && event.y < @last_y + @last_h
            clicked_row = event.y - @last_y
            line_idx = @scroll_offset + clicked_row
            if line_idx >= 0 && line_idx < lines.size
              @highlighted_line = @start_line + line_idx
              return true
            end
          end
        end

        false
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        @last_x = x
        @last_y = y
        @last_w = width
        @last_h = height

        th = current_theme
        glyphs = th.glyphs
        gutter_c = @gutter_fg || th.text_muted
        cursor_c = @cursor_fg || th.warning
        indicator = @cursor_indicator || glyphs.cursor

        # Erase entire code view viewport with spaces to eliminate dirty trailing cells
        buffer.fill(x, y, width, height, ' ')

        all_lines = lines
        total_lines = all_lines.size
        gutter_w = @show_line_numbers ? calculate_gutter_width(total_lines) : 0
        content_w = Math.max(0, width - gutter_w)

        visible_lines = all_lines[@scroll_offset...@scroll_offset + height]? || [] of String

        buffer.with_clip(x, y, width, height) do
          visible_lines.each_with_index do |line_text, idx|
            cur_y = y + idx
            line_num = @start_line + @scroll_offset + idx
            is_highlighted = (@highlighted_line == line_num)

            # Render line number gutter
            if @show_line_numbers && gutter_w > 0 && width > 0
              num_str = line_num.to_s
              pad_w = Math.max(0, gutter_w - 3) # account for ' │ '
              indicator_w = VisualWidth.width(indicator)

              if is_highlighted
                rem_w = Math.max(0, pad_w - indicator_w)
                buffer.put_string(x, cur_y, indicator, fg: cursor_c, bold: true, max_width: width)
                avail_num = Math.max(0, width - indicator_w)
                buffer.put_string(x + indicator_w, cur_y, num_str.rjust(rem_w), fg: cursor_c, bold: true, max_width: avail_num)
                avail_div = Math.max(0, width - pad_w)
                buffer.put_string(x + pad_w, cur_y, " │ ", fg: gutter_c, max_width: avail_div)
              else
                buffer.put_string(x, cur_y, num_str.rjust(pad_w), fg: gutter_c, max_width: width)
                avail_div = Math.max(0, width - pad_w)
                buffer.put_string(x + pad_w, cur_y, " │ ", fg: gutter_c, max_width: avail_div)
              end
            end

            # Render syntax-highlighted tokens for this line
            if content_w > 0 && x + gutter_w < x + width
              render_line_tokens(buffer, x + gutter_w, cur_y, line_text, content_w, is_highlighted)
            end
          end
        end
      end

      private def calculate_gutter_width(total_lines : Int32) : Int32
        max_num = @start_line + total_lines - 1
        digits = Math.max(2, max_num.to_s.size)
        digits + 4 # e.g. " 123 │ "
      end

      private def render_line_tokens(
        buffer : Buffer,
        start_x : Int32,
        y : Int32,
        line : String,
        max_width : Int32,
        highlight : Bool,
      ) : Nil
        cur_x = start_x

        case @language
        when :asm, :assembly
          tokens = tokenize_asm(line)
        when :c, :pseudoc
          tokens = tokenize_c(line)
        when :crystal, :ruby
          tokens = tokenize_crystal(line)
        else
          tokens = [{line, Color.none, false, false}]
        end

        hl_fg = @cursor_fg || current_theme.warning

        tokens.each do |text, fg, bold, dim|
          break if cur_x >= start_x + max_width
          avail = (start_x + max_width) - cur_x

          buffer.put_string(
            cur_x, y, text,
            fg: highlight ? (fg.type == Color::Type::None ? hl_fg : fg) : fg,
            bold: highlight ? true : bold,
            dim: dim,
            max_width: avail
          )
          cur_x += VisualWidth.width(text)
        end
      end

      private def tokenize_asm(line : String) : Array(Tuple(String, Color, Bool, Bool))
        tokens = [] of Tuple(String, Color, Bool, Bool)
        return tokens if line.empty?

        # Check for full-line or trailing comment
        comment_idx = line.index(';') || line.index("//")
        code_part = comment_idx ? line[0...comment_idx] : line
        comment_part = comment_idx ? line[comment_idx..] : nil

        # Regex scan code tokens
        scanner = StringScanner.new(code_part)
        until scanner.eos?
          if match = scanner.scan(/\s+/)
            tokens << {match, Color.none, false, false}
          elsif match = scanner.scan(/0x[0-9a-fA-F]+\b|\b\d+\b/)
            tokens << {match, Color.from(:yellow), false, false}
          elsif match = scanner.scan(/\b(rax|rbx|rcx|rdx|rsi|rdi|rsp|rbp|rip|r[89]|r1[0-5]|eax|ebx|ecx|edx|esi|edi|esp|ebp|eip|ax|bx|cx|dx|si|di|sp|bp|al|bl|cl|dl|ah|bh|ch|dh|r[89][bdw]|r1[0-5][bdw]|xmm[0-9]|xmm1[0-5]|ymm[0-9]|ymm1[0-5])\b/i)
            tokens << {match, Color.from(:cyan), true, false}
          elsif match = scanner.scan(/\b(mov|movzx|movsx|lea|push|pop|call|ret|retn|jmp|je|jne|jz|jnz|ja|jae|jb|jbe|jg|jge|jl|jle|cmp|test|add|sub|inc|dec|imul|idiv|mul|div|xor|and|or|not|shl|shr|sar|nop|syscall|int3|int|leave|enter)\b/i)
            tokens << {match, Color.from(:bright_blue), true, false}
          elsif match = scanner.scan(/"[^"]*"/)
            tokens << {match, Color.from(:green), false, false}
          elsif match = scanner.scan(/[\[\],+\-*:]/)
            tokens << {match, Color.from(:dark_gray), false, false}
          elsif match = scanner.scan(/[^\s0-9a-zA-Z_\[\],+\-*:]+/)
            tokens << {match, Color.none, false, false}
          elsif match = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_.]*/)
            tokens << {match, Color.none, false, false}
          else
            tokens << {(scanner.scan(/./m) || ""), Color.none, false, false}
          end
        end

        if comment_part
          tokens << {comment_part, Color.from(:gray), false, true}
        end

        tokens
      end

      private def tokenize_c(line : String) : Array(Tuple(String, Color, Bool, Bool))
        tokens = [] of Tuple(String, Color, Bool, Bool)
        return tokens if line.empty?

        comment_idx = line.index("//")
        code_part = comment_idx ? line[0...comment_idx] : line
        comment_part = comment_idx ? line[comment_idx..] : nil

        scanner = StringScanner.new(code_part)
        until scanner.eos?
          if match = scanner.scan(/\s+/)
            tokens << {match, Color.none, false, false}
          elsif match = scanner.scan(/0x[0-9a-fA-F]+\b|\b\d+(\.\d+)?\b/)
            tokens << {match, Color.from(:yellow), false, false}
          elsif match = scanner.scan(/\b(int|void|char|float|double|size_t|uint64_t|int64_t|uint32_t|int32_t|uint8_t|int8_t|bool|return|if|else|while|for|do|switch|case|default|break|continue|goto|struct|union|enum|typedef|const|static|volatile|inline|extern|sizeof|NULL)\b/)
            tokens << {match, Color.from(:magenta), true, false}
          elsif match = scanner.scan(/"[^"]*"|'[^']*'/)
            tokens << {match, Color.from(:green), false, false}
          elsif match = scanner.scan(/[(){}\[\];,.]/)
            tokens << {match, Color.from(:dark_gray), false, false}
          elsif match = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*/)
            tokens << {match, Color.none, false, false}
          else
            tokens << {(scanner.scan(/./m) || ""), Color.none, false, false}
          end
        end

        if comment_part
          tokens << {comment_part, Color.from(:gray), false, true}
        end

        tokens
      end

      private def tokenize_crystal(line : String) : Array(Tuple(String, Color, Bool, Bool))
        tokens = [] of Tuple(String, Color, Bool, Bool)
        return tokens if line.empty?

        comment_idx = line.index('#')
        code_part = comment_idx ? line[0...comment_idx] : line
        comment_part = comment_idx ? line[comment_idx..] : nil

        scanner = StringScanner.new(code_part)
        until scanner.eos?
          if match = scanner.scan(/\s+/)
            tokens << {match, Color.none, false, false}
          elsif match = scanner.scan(/0x[0-9a-fA-F]+\b|\b\d+(\.\d+)?(_[a-z0-9]+)?\b/)
            tokens << {match, Color.from(:yellow), false, false}
          elsif match = scanner.scan(/\b(def|class|module|struct|enum|lib|type|alias|if|else|elsif|unless|while|until|case|when|then|return|break|next|yield|rescue|ensure|begin|end|do|self|nil|true|false|super|getter|setter|property)\b/)
            tokens << {match, Color.from(:magenta), true, false}
          elsif match = scanner.scan(/@[a-zA-Z0-9_]+/)
            tokens << {match, Color.from(:cyan), false, false}
          elsif match = scanner.scan(/:[a-zA-Z0-9_]+/)
            tokens << {match, Color.from(:yellow), false, false}
          elsif match = scanner.scan(/"[^"]*"/)
            tokens << {match, Color.from(:green), false, false}
          elsif match = scanner.scan(/[a-zA-Z_][a-zA-Z0-9_]*[?!]?/)
            tokens << {match, Color.none, false, false}
          else
            tokens << {(scanner.scan(/./m) || ""), Color.none, false, false}
          end
        end

        if comment_part
          tokens << {comment_part, Color.from(:gray), false, true}
        end

        tokens
      end

      # Preferred size in print mode: full line count
      def preferred_print_size(available_w : Int32) : {Int32, Int32}
        all_lines = lines
        gutter_w = @show_line_numbers ? calculate_gutter_width(all_lines.size) : 0
        max_line_w = all_lines.map { |l| VisualWidth.width(l) }.max? || 0
        total_w = gutter_w + max_line_w + 2
        {Math.max(total_w, available_w), all_lines.size}
      end

      # Render hook for print mode: resets scroll offset
      def render_print(buffer : Buffer, width : Int32, height : Int32) : Nil
        prev_offset = @scroll_offset
        @scroll_offset = 0
        begin
          render(buffer, 0, 0, width, height)
        ensure
          @scroll_offset = prev_offset
        end
      end

      # Class convenience method returning styled code string
      def self.to_string(
        code : String,
        language : Symbol | String = :plain,
        show_line_numbers : Bool = true,
        start_line : Int32 = 1,
        width : Int32? = nil,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : String
        cv = CodeView.new(
          code: code,
          language: language,
          show_line_numbers: show_line_numbers,
          start_line: start_line
        )
        cv.to_print_s(width: width, color: color, theme: theme)
      end

      # Class convenience method printing styled code directly to IO
      def self.print(
        code : String,
        language : Symbol | String = :plain,
        show_line_numbers : Bool = true,
        start_line : Int32 = 1,
        io : IO = STDOUT,
        width : Int32? = nil,
        color : Bool? = nil,
        theme : Theme? = nil,
      ) : Nil
        io.print to_string(
          code: code,
          language: language,
          show_line_numbers: show_line_numbers,
          start_line: start_line,
          width: width,
          color: color,
          theme: theme
        )
      end
    end
  end
end
