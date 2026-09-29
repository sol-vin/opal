require "string_scanner"
require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Code and disassembly viewing element with line numbers,
    # syntax highlighting, cursor indicator, and vertical scrolling.
    class CodeView < Element
      property code : String
      property language : Symbol # :asm, :c, :crystal, :plain
      property start_line : Int32
      property highlighted_line : Int32?
      property scroll_offset : Int32
      property? show_line_numbers : Bool
      property gutter_fg : Color
      property cursor_fg : Color
      property cursor_indicator : String

      def initialize(
        @code : String = "",
        @language : Symbol = :plain,
        @start_line : Int32 = 1,
        @highlighted_line : Int32? = nil,
        @scroll_offset : Int32 = 0,
        @show_line_numbers : Bool = true,
        gutter_fg : Color | Symbol | String = :dark_gray,
        cursor_fg : Color | Symbol | String = :yellow,
        @cursor_indicator : String = "▶ ",
      )
        @gutter_fg = Color.from(gutter_fg)
        @cursor_fg = Color.from(cursor_fg)
      end

      def lines : Array(String)
        @code.split('\n')
      end

      def scroll_up(count : Int32 = 1) : Nil
        @scroll_offset = Math.max(0, @scroll_offset - count)
      end

      def scroll_down(count : Int32 = 1) : Nil
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

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        all_lines = lines
        total_lines = all_lines.size
        gutter_w = @show_line_numbers ? calculate_gutter_width(total_lines) : 0
        content_w = Math.max(0, width - gutter_w)

        visible_lines = all_lines[@scroll_offset...@scroll_offset + height]? || [] of String

        visible_lines.each_with_index do |line_text, idx|
          cur_y = y + idx
          line_num = @start_line + @scroll_offset + idx
          is_highlighted = (@highlighted_line == line_num)

          # Render line number gutter
          if @show_line_numbers && gutter_w > 0
            num_str = line_num.to_s
            pad_w = gutter_w - 3 # account for ' │ '
            padded_num = num_str.rjust(pad_w)

            if is_highlighted
              buffer.put_string(x, cur_y, @cursor_indicator, fg: @cursor_fg, bold: true)
              buffer.put_string(x + 2, cur_y, padded_num[2..]? || padded_num, fg: @cursor_fg, bold: true)
              buffer.put_string(x + gutter_w - 3, cur_y, " │ ", fg: @gutter_fg)
            else
              buffer.put_string(x, cur_y, padded_num, fg: @gutter_fg)
              buffer.put_string(x + pad_w, cur_y, " │ ", fg: @gutter_fg)
            end
          end

          # Render syntax-highlighted tokens for this line
          render_line_tokens(buffer, x + gutter_w, cur_y, line_text, content_w, is_highlighted)
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

        tokens.each do |text, fg, bold, dim|
          break if cur_x >= start_x + max_width
          avail = (start_x + max_width) - cur_x

          buffer.put_string(
            cur_x, y, text,
            fg: highlight ? (fg.type == Color::Type::None ? @cursor_fg : fg) : fg,
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
    end
  end
end
