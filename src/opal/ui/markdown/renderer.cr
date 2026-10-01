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

    # Markdown Element / Viewer for use inside UI trees with interactive scrolling
    class MarkdownElement < Element
      getter content : String
      getter rendered : String
      property scroll_offset : Int32 = 0
      property visible_height : Int32 = 20
      property? scrollable : Bool = true
      property? auto_scroll : Bool = false
      property scroll_speed : Float64 = 1.0
      @scroll_accumulator : Float64 = 0.0

      def initialize(
        @content : String,
        width : Int32 = 80,
        @scrollable : Bool = true,
        @auto_scroll : Bool = false,
        @scroll_speed : Float64 = 1.0,
      )
        super()
        renderer = Markdown::Renderer.new(width)
        @rendered = renderer.render(@content)
      end

      def content=(new_content : String)
        set_content(new_content, 80)
      end

      def set_content(new_content : String, width : Int32 = 80)
        @content = new_content
        @rendered = Markdown::Renderer.new(width).render(new_content)
        @scroll_offset = 0
      end

      def tick(dt : Float64 = 0.0166) : Nil
        return unless @auto_scroll
        @scroll_accumulator += dt * @scroll_speed * 2.0
        if @scroll_accumulator >= 1.0
          steps = @scroll_accumulator.to_i
          @scroll_accumulator -= steps
          all_lines = lines
          max_scroll = Math.max(0, all_lines.size - @visible_height)
          if @scroll_offset >= max_scroll
            @scroll_offset = 0
          else
            @scroll_offset = Math.min(max_scroll, @scroll_offset + steps)
          end
        end
      end

      def lines : Array(String)
        @rendered.split('\n')
      end

      def page_up(lines_count : Int32? = nil) : Nil
        return unless @scrollable
        step = lines_count || Math.max(1, @visible_height - 2)
        scroll_up(step)
      end

      def page_down(lines_count : Int32? = nil) : Nil
        return unless @scrollable
        step = lines_count || Math.max(1, @visible_height - 2)
        scroll_down(step)
      end

      def scroll_up(lines_count : Int32 = 1) : Nil
        return unless @scrollable
        @scroll_offset = Math.max(0, @scroll_offset - lines_count)
      end

      def scroll_down(lines_count : Int32 = 1) : Nil
        return unless @scrollable
        all_lines = lines
        max_scroll = Math.max(0, all_lines.size - @visible_height)
        @scroll_offset = Math.min(max_scroll, @scroll_offset + lines_count)
      end

      def scroll_to_top : Nil
        return unless @scrollable
        @scroll_offset = 0
      end

      def scroll_to_bottom : Nil
        return unless @scrollable
        all_lines = lines
        @scroll_offset = Math.max(0, all_lines.size - @visible_height)
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        return false unless @scrollable
        case key.name
        when "page_up", "pageup"
          page_up
          true
        when "page_down", "pagedown"
          page_down
          true
        when "up", "k"
          scroll_up(1)
          true
        when "down", "j"
          scroll_down(1)
          true
        when "home"
          scroll_to_top
          true
        when "end"
          scroll_to_bottom
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false unless @scrollable
        case event.button
        when Terminal::MouseButton::WheelUp
          scroll_up(3)
          true
        when Terminal::MouseButton::WheelDown
          scroll_down(3)
          true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        all_lines = lines
        h = all_lines.size
        w = all_lines.map { |l| VisualWidth.width(l) }.max? || 0
        {[w, available_w].min, [h, available_h].min}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        # Erase entire markdown viewport with spaces to eliminate dirty trailing cells
        buffer.fill(x, y, width, height, ' ')

        @visible_height = height
        all_lines = lines
        total_lines = all_lines.size
        max_scroll = Math.max(0, total_lines - height)
        @scroll_offset = @scroll_offset.clamp(0, max_scroll)

        visible = all_lines[@scroll_offset...@scroll_offset + height]? || [] of String
        visible.each_with_index do |line, idx|
          break if y + idx >= y + height
          buffer.put_string(x, y + idx, line, max_width: width - (total_lines > height ? 2 : 0))
        end

        # Draw subtle vertical scrollbar if content exceeds container height
        if total_lines > height && height > 2
          bar_x = x + width - 1
          thumb_pos = ((@scroll_offset.to_f / max_scroll.to_f) * (height - 1)).round.to_i.clamp(0, height - 1)

          (0...height).each do |sy|
            char = (sy == thumb_pos) ? '█' : '│'
            fg_color = (sy == thumb_pos) ? Color.cyan : Color.bright_black
            buffer.put_char(bar_x, y + sy, char, fg: fg_color)
          end
        end
      end
    end

    alias MarkdownViewer = MarkdownElement

    # Async Markdown Viewer that displays an animated throbber until markdown string is ready
    class AsyncMarkdownViewer < Element
      property viewer : MarkdownViewer? = nil
      property? resolved : Bool = false
      property label : String
      property spinner_frame : Int32 = 0
      property width : Int32
      property? scrollable : Bool = true
      property? auto_scroll : Bool = false
      property scroll_speed : Float64 = 1.0

      def initialize(
        @label : String = "Loading markdown...",
        @width : Int32 = 80,
        @scrollable : Bool = true,
        @auto_scroll : Bool = false,
        @scroll_speed : Float64 = 1.0,
        &block : -> String
      )
        super()
        spawn do
          result = block.call
          v = MarkdownViewer.new(
            result,
            width: @width,
            scrollable: @scrollable,
            auto_scroll: @auto_scroll,
            scroll_speed: @scroll_speed
          )
          @viewer = v
          @resolved = true
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if v = @viewer
          v.preferred_size(available_w, available_h)
        else
          {available_w, available_h}
        end
      end

      def tick(dt : Float64 = 0.0166) : Nil
        if v = @viewer
          v.tick(dt)
        else
          @spinner_frame += 1
        end
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        if v = @viewer
          v.handle_key(key)
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if v = @viewer
          v.handle_mouse(event)
        else
          false
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        if v = @viewer
          v.render(buffer, x, y, width, height)
        else
          th = current_theme
          glyphs = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
          spinner = glyphs[@spinner_frame % glyphs.size]
          mid_y = y + (height // 2)
          mid_x = x + Math.max(0, (width - @label.size - 4) // 2)
          buffer.put_string(mid_x, mid_y, "#{spinner} #{@label}", fg: th.primary)
        end
      end
    end

    module Markdown
      # Renders Markdown text directly to an ANSI formatted string.
      def self.render(text : String, width : Int32? = nil) : String
        w = width || (Terminal::Info.new.width rescue 80)
        Renderer.new(w).render(text)
      end

      # Prints rendered Markdown directly to IO.
      def self.print(text : String, io : IO = STDOUT, width : Int32? = nil) : Nil
        io.print render(text, width)
      end
    end
  end

  # Renders Markdown text directly to an ANSI formatted string.
  def self.render_markdown(text : String, width : Int32 = 80) : String
    UI::Markdown::Renderer.new(width).render(text)
  end

  # Prints Markdown text directly to IO stream.
  def self.print_markdown(text : String, io : IO = STDOUT, width : Int32? = nil) : Nil
    UI::Markdown.print(text, io, width)
  end
end
