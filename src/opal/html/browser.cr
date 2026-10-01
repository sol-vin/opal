require "./parser"
require "../ui/element"
require "../ui/buffer"
require "../style/color"
require "../style/glyphs"
require "../terminal/osc"

module Opal
  module UI
    # Interactive TUI web browser component with address bar, back/forward history,
    # OSC 8 terminal hyperlinks, HTML tag rendering, formatted tables, and link clicking.
    class HTMLBrowser < Element
      property url : String
      property history : Array(String) = [] of String
      property history_index : Int32 = -1
      property scroll_y : Int32 = 0
      property? enable_osc8 : Bool = true
      property hover_link : String? = nil
      property focused_link_idx : Int32? = nil

      @root_node : HTML::Node? = nil
      @raw_html : String = ""
      @links = [] of Tuple(Rect, String) # Screen hit-boxes for links
      @on_navigate_handler : (String -> Nil)?

      def initialize(@url : String = "about:home", @enable_osc8 : Bool = true)
        load_default_page(@url)
      end

      def on_navigate(&block : String -> Nil) : self
        @on_navigate_handler = block
        self
      end

      def load_html(html : String, new_url : String? = nil, record_history : Bool = true) : Nil
        @raw_html = html
        @root_node = HTML::Parser.parse(html)
        if target_url = new_url
          @url = target_url
          if record_history
            if @history_index == -1 || @history[@history_index]? != target_url
              @history = @history[0..@history_index] if @history_index >= 0
              @history << target_url
              @history_index = @history.size - 1
            end
          end
        end
        @scroll_y = 0
        @links.clear
        @focused_link_idx = nil
      end

      def navigate_to(target_url : String) : Nil
        if handler = @on_navigate_handler
          handler.call(target_url)
        else
          load_default_page(target_url)
        end
      end

      def back : Nil
        if @history_index > 0
          @history_index -= 1
          target = @history[@history_index]
          @url = target
          load_default_page(target, record_history: false)
        end
      end

      def forward : Nil
        if @history_index < @history.size - 1
          @history_index += 1
          target = @history[@history_index]
          @url = target
          load_default_page(target, record_history: false)
        end
      end

      def scroll_down(n : Int32 = 1) : Nil
        @scroll_y += n
      end

      def scroll_up(n : Int32 = 1) : Nil
        @scroll_y = Math.max(0, @scroll_y - n)
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "up", "k"
          scroll_up(1)
          true
        when "down", "j"
          scroll_down(1)
          true
        when "page_up", "pageup"
          scroll_up(10)
          true
        when "page_down", "pagedown"
          scroll_down(10)
          true
        when "left", "backspace"
          back
          true
        when "right"
          forward
          true
        else
          false
        end
      end

      def handle_click(x : Int32, y : Int32) : Bool
        # Check toolbar buttons
        if y == 0
          if x >= 1 && x <= 4
            back
            return true
          elsif x >= 6 && x <= 9
            forward
            return true
          end
        end

        # Check links
        @links.each do |(rect, href)|
          if rect.in_bounds?(x, y)
            navigate_to(href)
            return true
          end
        end

        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        @links.clear
        return if width <= 0 || height <= 0

        # --- Row 0: Address Bar & Toolbar ---
        buffer.fill(x, y, width, 1, Cell.new(bg: Color.hex("#1e293b")))
        can_back = @history_index > 0
        can_fwd = @history_index < @history.size - 1

        buffer.put_string(x + 1, y, "[<]", fg: can_back ? Color.hex("#38ef7d") : Color.ansi(240), bold: can_back)
        buffer.put_string(x + 5, y, "[>]", fg: can_fwd ? Color.hex("#38ef7d") : Color.ansi(240), bold: can_fwd)
        buffer.put_string(x + 10, y, "URL:", fg: Color.hex("#94a3b8"), dim: true)
        buffer.put_string(x + 15, y, @url, fg: Color.white, bold: true)

        # Separator line
        (0...width).each { |i| buffer.put_char(x + i, y + 1, '─', fg: Color.hex("#334155")) }

        # --- Document Viewport ---
        doc_y = y + 2
        doc_h = height - 3
        buffer.with_scissor(Rect.new(x, doc_y, width, doc_h)) do
          if root = @root_node
            render_node_children(root, buffer, x + 2, doc_y - @scroll_y, width - 4)
          end
        end

        # --- Bottom Status Bar ---
        status_y = y + height - 1
        buffer.fill(x, status_y, width, 1, Cell.new(bg: Color.hex("#0f172a")))
        if hover = @hover_link
          buffer.put_string(x + 1, status_y, "Link: #{hover}", fg: Color.hex("#38ef7d"))
        else
          buffer.put_string(x + 1, status_y, "OpalBrowser 1.0 - [Tab] cycle links, [Enter] visit, [ESC] exit", fg: Color.hex("#64748b"))
        end
      end

      private def render_node_children(parent : HTML::Node, buffer : Buffer, ox : Int32, cur_y : Int32, max_w : Int32) : Int32
        y = cur_y
        parent.children.each do |child|
          y = render_node(child, buffer, ox, y, max_w)
        end
        y
      end

      private def render_node(node : HTML::Node, buffer : Buffer, ox : Int32, cur_y : Int32, max_w : Int32) : Int32
        case node.type
        when HTML::TagType::H1
          buffer.put_string(ox, cur_y, extract_text(node), fg: Color.hex("#00f2fe"), bold: true, underline: true)
          cur_y + 2
        when HTML::TagType::H2
          buffer.put_string(ox, cur_y, "## " + extract_text(node), fg: Color.hex("#38ef7d"), bold: true)
          cur_y + 2
        when HTML::TagType::H3
          buffer.put_string(ox, cur_y, "### " + extract_text(node), fg: Color.hex("#f6d365"), bold: true)
          cur_y + 2
        when HTML::TagType::Paragraph
          txt = extract_text(node)
          lines = wrap_text(txt, max_w)
          lines.each do |l|
            buffer.put_string(ox, cur_y, l, fg: Color.hex("#e2e8f0"))
            cur_y += 1
          end
          cur_y + 1
        when HTML::TagType::Link
          href = node.href || "#"
          txt = extract_text(node)
          txt = href if txt.empty?
          # Record hitbox
          rect = Rect.new(ox, cur_y, txt.size, 1)
          @links << {rect, href}

          link_str = @enable_osc8 ? Terminal::OSC.hyperlink(txt, href) : txt
          buffer.put_string(ox, cur_y, link_str, fg: Color.hex("#4facfe"), underline: true, bold: true)
          cur_y + 1
        when HTML::TagType::ListItem
          txt = extract_text(node)
          buffer.put_char(ox, cur_y, '•', fg: Color.hex("#38ef7d"))
          buffer.put_string(ox + 2, cur_y, txt, fg: Color.white)
          cur_y + 1
        when HTML::TagType::Rule
          (0...max_w).each { |i| buffer.put_char(ox + i, cur_y, '─', fg: Color.ansi(240)) }
          cur_y + 2
        when HTML::TagType::Blockquote
          txt = extract_text(node)
          buffer.put_char(ox, cur_y, '│', fg: Color.hex("#f6d365"), bold: true)
          buffer.put_string(ox + 2, cur_y, txt, fg: Color.hex("#cbd5e1"), italic: true)
          cur_y + 2
        when HTML::TagType::Code, HTML::TagType::Pre
          txt = extract_text(node)
          buffer.fill(ox, cur_y, max_w, 1, Cell.new(bg: Color.hex("#1e293b")))
          buffer.put_string(ox + 1, cur_y, txt, fg: Color.hex("#38ef7d"))
          cur_y + 2
        when HTML::TagType::Table
          render_table_node(node, buffer, ox, cur_y, max_w)
        else
          if !node.children.empty?
            render_node_children(node, buffer, ox, cur_y, max_w)
          else
            txt = node.content.strip
            if !txt.empty?
              buffer.put_string(ox, cur_y, txt, fg: Color.white)
              cur_y + 1
            else
              cur_y
            end
          end
        end
      end

      private def render_table_node(node : HTML::Node, buffer : Buffer, ox : Int32, cur_y : Int32, max_w : Int32) : Int32
        y = cur_y
        node.children.select { |c| c.type == HTML::TagType::TableRow }.each do |row|
          col_x = ox
          row.children.each do |cell|
            txt = extract_text(cell)
            col_w = Math.max(12, txt.size + 2)
            is_th = cell.type == HTML::TagType::TableHeader
            fg_col = is_th ? Color.hex("#38ef7d") : Color.white
            buffer.put_string(col_x, y, "[ #{txt} ]", fg: fg_col, bold: is_th)
            col_x += col_w + 2
          end
          y += 1
        end
        y + 1
      end

      private def extract_text(node : HTML::Node) : String
        return node.content unless node.content.empty?
        node.children.map { |c| extract_text(c) }.join(" ").strip
      end

      private def wrap_text(text : String, max_w : Int32) : Array(String)
        words = text.split
        lines = [] of String
        cur = ""
        words.each do |w|
          if cur.empty?
            cur = w
          elsif (cur.size + 1 + w.size) <= max_w
            cur += " " + w
          else
            lines << cur
            cur = w
          end
        end
        lines << cur unless cur.empty?
        lines
      end

      private def load_default_page(url_key : String, record_history : Bool = true)
        html = case url_key
               when "about:opal", "about:home"
                 <<-HTML
                 <h1>Welcome to Opal TUI Browser</h1>
                 <p>Experience the next generation of terminal document rendering.</p>
                 <hr/>
                 <h2>Supported HTML Elements</h2>
                 <ul>
                   <li>Headings 1 through 6</li>
                   <li>Hyperlinks with OSC 8 support</li>
                   <li>Tables and List Items</li>
                   <li>Preformatted code and blockquotes</li>
                 </ul>
                 <p>Explore links: <a href="about:features">View Features</a> | <a href="about:team">The sol.vin Team</a></p>
                 HTML
               when "about:features"
                 <<-HTML
                 <h1>Opal Framework Features</h1>
                 <p>Complete suite of declarative terminal primitives:</p>
                 <table>
                   <tr><th>Feature</th><th>Module</th><th>Status</th></tr>
                   <tr><td>Scissor Mode</td><td>opal/ui</td><td>Active</td></tr>
                   <tr><td>Alpha Masks</td><td>opal/ui</td><td>Active</td></tr>
                   <tr><td>Mermaid Diagrams</td><td>opal/mermaid</td><td>Active</td></tr>
                   <tr><td>Game Loop 60Hz</td><td>opal/game</td><td>Active</td></tr>
                 </table>
                 <p><a href="about:home">Back to Home</a></p>
                 HTML
               else
                 <<-HTML
                 <h1>Document: #{url_key}</h1>
                 <p>Showing content for #{url_key}</p>
                 <p><a href="about:home">Return Home</a></p>
                 HTML
               end
        load_html(html, url_key, record_history: record_history)
      end
    end
  end
end
