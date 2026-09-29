require "../../style/color"
require "../../style/visual_width"
require "../../terminal/osc"

module Opal
  module UI
    module Markdown
      # Renders Markdown text into ANSI styled terminal text.
      class Renderer
        getter width : Int32

        def initialize(@width : Int32 = 80)
        end

        def render(text : String) : String
          lines = text.split('\n')
          output = IO::Memory.new

          in_code_block = false
          code_lang = ""
          code_lines = [] of String

          idx = 0
          while idx < lines.size
            line = lines[idx]

            # Fenced code block detection
            if line.starts_with?("```")
              if in_code_block
                render_code_block(output, code_lang, code_lines)
                in_code_block = false
                code_lines.clear
              else
                in_code_block = true
                code_lang = line.lstrip("`").strip
              end
              idx += 1
              next
            end

            if in_code_block
              code_lines << line
              idx += 1
              next
            end

            # Headers
            if line.starts_with?("# ")
              render_header(output, 1, line[2..].strip)
            elsif line.starts_with?("## ")
              render_header(output, 2, line[3..].strip)
            elsif line.starts_with?("### ")
              render_header(output, 3, line[4..].strip)
            elsif line.starts_with?("#### ")
              render_header(output, 4, line[5..].strip)
            elsif line.starts_with?("> ") # Blockquote
              render_blockquote(output, line[2..].strip)
            elsif line =~ /^[-*+]\s+/ # Unordered list
              bullet_content = line.sub(/^[-*+]\s+/, "")
              render_list_item(output, "•", bullet_content)
            elsif line =~ /^\d+\.\s+/ # Ordered list
              num = line[/^\d+\./]
              num_content = line.sub(/^\d+\.\s+/, "")
              render_list_item(output, num, num_content)
            elsif line =~ /^---+$|^===+$|^\*\*\*+$/ # Horizontal rule
              output.puts "\e[90m" + ("─" * @width) + "\e[0m"
            elsif line.strip.empty?
              output.puts
            else # Paragraph
              render_paragraph(output, line)
            end

            idx += 1
          end

          # If code block never closed
          if in_code_block && !code_lines.empty?
            render_code_block(output, code_lang, code_lines)
          end

          output.to_s
        end

        private def render_header(io : IO, level : Int32, text : String) : Nil
          styled_text = format_inline(text)
          case level
          when 1
            io.puts
            io.puts "\e[1;35;4m# #{styled_text}\e[0m"
            io.puts
          when 2
            io.puts
            io.puts "\e[1;36m## #{styled_text}\e[0m"
          when 3
            io.puts "\e[1;34m### #{styled_text}\e[0m"
          else
            io.puts "\e[1;37m#{styled_text}\e[0m"
          end
        end

        private def render_blockquote(io : IO, text : String) : Nil
          styled_text = format_inline(text)
          io.puts "\e[90m│\e[0m \e[3;90m#{styled_text}\e[0m"
        end

        private def render_list_item(io : IO, prefix : String, text : String) : Nil
          styled_text = format_inline(text)
          io.puts "  \e[36m#{prefix}\e[0m #{styled_text}"
        end

        private def render_paragraph(io : IO, text : String) : Nil
          io.puts format_inline(text)
        end

        private def render_code_block(io : IO, lang : String, lines : Array(String)) : Nil
          io.puts
          # Header line with language tag
          lang_tag = lang.empty? ? "" : " [#{lang}]"
          border_len = Math.max(0, @width - VisualWidth.width(lang_tag) - 3)
          io.puts "\e[90m┌─\e[36m#{lang_tag}\e[90m" + ("─" * border_len) + "┐\e[0m"

          lines.each do |code_line|
            highlighted = highlight_syntax(code_line)
            # Pad line to width
            clean_w = VisualWidth.width(code_line)
            pad = Math.max(0, @width - clean_w - 4)
            io.puts "\e[90m│\e[0m  #{highlighted}#{" " * pad}\e[90m│\e[0m"
          end

          io.puts "\e[90m└" + ("─" * (@width - 2)) + "┘\e[0m"
          io.puts
        end

        # Lightweight keyword & literal syntax highlighter
        private def highlight_syntax(code : String) : String
          # Comments
          if code.lstrip.starts_with?('#') || code.lstrip.starts_with?("//")
            return "\e[90m#{code}\e[0m"
          end

          res = code

          # Strings: "..." or '...'
          res = res.gsub(/"([^"\\]|\\.)*"/) { |match| "\e[32m#{match}\e[0m" }
          res = res.gsub(/'([^'\\]|\\.)*'/) { |match| "\e[32m#{match}\e[0m" }

          # Common keywords
          keywords = [
            "def", "class", "module", "struct", "enum", "if", "else", "elsif",
            "end", "return", "require", "include", "extend", "do", "case", "when",
            "true", "false", "nil", "null", "fn", "let", "const", "function",
            "async", "await", "import", "export", "while", "for", "in", "break",
          ]

          keywords.each do |kw|
            res = res.gsub(/\b#{Regex.escape(kw)}\b/, "\e[1;35m#{kw}\e[0m")
          end

          # Numbers
          res = res.gsub(/\b\d+(\.\d+)?\b/, "\e[33m\\0\e[0m")

          res
        end

        # Formats inline formatting: bold, italic, code, links
        def format_inline(text : String) : String
          res = text

          # Links: [title](url) -> OSC 8 or titled link
          res = res.gsub(/\[([^\]]+)\]\(([^)]+)\)/) do |match|
            title = $1
            url = $2
            Terminal::OSC.hyperlink(title, url)
          end

          # Inline code: `code`
          res = res.gsub(/`([^`]+)`/) do
            code = $1
            "\e[36m#{code}\e[0m"
          end

          # Bold: **bold** or __bold__
          res = res.gsub(/\*\*([^*]+)\*\*/) { "\e[1m#{$1}\e[0m" }
          res = res.gsub(/__([^_]+)__/) { "\e[1m#{$1}\e[0m" }

          # Italic: *italic* or _italic_
          res = res.gsub(/(?<!\*)\*([^*]+)\*(?!\*)/) { "\e[3m#{$1}\e[0m" }

          # Strikethrough: ~~strike~~
          res = res.gsub(/~~([^~]+)~~/) { "\e[9m#{$1}\e[0m" }

          res
        end
      end
    end

    # Markdown Element for use inside UI trees
    class MarkdownElement < Element
      getter content : String
      getter rendered : String

      def initialize(@content : String, width : Int32 = 80)
        renderer = Markdown::Renderer.new(width)
        @rendered = renderer.render(@content)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        lines = @rendered.split('\n')
        h = lines.size
        w = lines.map { |l| VisualWidth.width(l) }.max? || 0
        {[w, available_w].min, [h, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        lines = @rendered.split('\n')
        lines.each_with_index do |line, idx|
          break if y + idx >= y + height
          buffer.put_string(x, y + idx, line, max_width: width)
        end
      end
    end
  end

  # Renders Markdown text directly to an ANSI formatted string.
  def self.render_markdown(text : String, width : Int32 = 80) : String
    UI::Markdown::Renderer.new(width).render(text)
  end
end
