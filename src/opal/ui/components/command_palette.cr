require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"
require "../../input/fuzzy"

module Opal
  module UI
    # Represents an actionable command in a CommandPalette
    class CommandAction
      getter id : String
      getter title : String
      getter category : String
      getter shortcut : String?
      getter callback : Proc(Nil)?

      def initialize(
        @id : String,
        @title : String,
        @category : String = "General",
        @shortcut : String? = nil,
        @callback : Proc(Nil)? = nil,
      )
      end

      def full_search_key : String
        "#{@category}: #{@title}"
      end
    end

    # Spotlight / Quick Launcher overlay modal for searchable actions and hotkeys.
    class CommandPalette < Element
      getter actions : Array(CommandAction)
      property query : String = ""
      property cursor : Int32 = 0
      property? visible : Bool = true

      def initialize(@actions : Array(CommandAction) = [] of CommandAction)
      end

      def add(action : CommandAction) : Nil
        @actions << action
      end

      def add(id : String, title : String, category : String = "General", shortcut : String? = nil) : CommandAction
        action = CommandAction.new(id, title, category, shortcut)
        @actions << action
        action
      end

      def add(id : String, title : String, category : String = "General", shortcut : String? = nil, &block : -> Nil) : CommandAction
        action = CommandAction.new(id, title, category, shortcut, block)
        @actions << action
        action
      end

      def matches : Array(Input::FuzzyMatch(CommandAction))
        Input::Fuzzy.filter_by(@query, @actions) { |act| act.full_search_key }
      end

      def selected_action : CommandAction?
        m = matches
        return nil if m.empty?
        idx = @cursor.clamp(0, Math.max(0, m.size - 1))
        m[idx].item
      end

      def cursor_up : Nil
        @cursor = Math.max(0, @cursor - 1)
      end

      def cursor_down : Nil
        max_idx = Math.max(0, matches.size - 1)
        @cursor = Math.min(max_idx, @cursor + 1)
      end

      def append_char(ch : Char) : Nil
        @query += ch
        @cursor = 0
      end

      def backspace : Nil
        return if @query.empty?
        @query = @query[0...-1]
        @cursor = 0
      end

      def execute_selected : CommandAction?
        if act = selected_item
          act.callback.try(&.call)
          act
        else
          nil
        end
      end

      # Alias
      def selected_item : CommandAction?
        selected_action
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = Math.min(Math.max(20, available_w - 4), 64)
        h = Math.min(Math.max(6, available_h - 2), 16)
        {w, h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return unless @visible
        buffer.dim_all

        pal_w, pal_h = preferred_size(width, height)
        pal_x = x + (width - pal_w) // 2
        pal_y = y + Math.max(1, (height - pal_h) // 3)

        # Draw card in sub-buffer
        card_buf = Buffer.new(pal_w, pal_h)

        b = Border.rounded
        # Top border with title
        card_buf.put_string(0, 0, b.top_left, fg: Color.cyan)
        card_buf.put_string(1, 0, b.top * (pal_w - 2), fg: Color.cyan)
        card_buf.put_string(pal_w - 1, 0, b.top_right, fg: Color.cyan)
        card_buf.put_string(2, 0, " Command Palette ", fg: Color.white, bold: true)

        # Clear background inside
        (1...(pal_h - 1)).each do |cur_y|
          card_buf.put_string(0, cur_y, b.left, fg: Color.cyan)
          card_buf.put_string(1, cur_y, " " * (pal_w - 2))
          card_buf.put_string(pal_w - 1, cur_y, b.right, fg: Color.cyan)
        end

        card_buf.put_string(0, pal_h - 1, b.bottom_left, fg: Color.cyan)
        card_buf.put_string(1, pal_h - 1, b.bottom * (pal_w - 2), fg: Color.cyan)
        card_buf.put_string(pal_w - 1, pal_h - 1, b.bottom_right, fg: Color.cyan)

        # Search box on line 1
        card_buf.put_string(2, 1, "[?] ", fg: Color.cyan)
        search_prompt = @query.empty? ? "Type a command..." : @query
        prompt_fg = @query.empty? ? Color.bright_black : Color.white
        max_prompt_w = pal_w - 7
        card_buf.put_string(5, 1, VisualWidth.truncate(search_prompt, max_prompt_w), fg: prompt_fg)
        cursor_x = 5 + VisualWidth.width(@query)
        card_buf.put_char(cursor_x, 1, '█', fg: Color.cyan) if !@query.empty? && cursor_x < pal_w - 1

        card_buf.put_string(1, 2, "─" * (pal_w - 2), fg: Color.bright_black)

        matched = matches
        list_h = pal_h - 4

        if matched.empty?
          card_buf.put_string(3, 3, "No matching commands", fg: Color.bright_black, italic: true)
        else
          (0...list_h).each do |line_idx|
            break if line_idx >= matched.size
            m = matched[line_idx]
            act = m.item
            is_active = (line_idx == @cursor)
            row_y = 3 + line_idx

            if is_active
              card_buf.put_string(2, row_y, "> ", fg: Color.cyan, bold: true)
            else
              card_buf.put_string(2, row_y, "  ")
            end

            # Category pill
            cat_str = "[#{act.category}]"
            card_buf.put_string(4, row_y, cat_str, fg: is_active ? Color.cyan : Color.bright_black)

            # Shortcut pill on the right
            sc_x = pal_w - 1
            if sc = act.shortcut
              sc_str = "<#{sc}>"
              sc_x = pal_w - VisualWidth.width(sc_str) - 3
              card_buf.put_string(sc_x, row_y, sc_str, fg: is_active ? Color.yellow : Color.bright_black)
            end

            # Action title
            title_x = 4 + VisualWidth.width(cat_str) + 1
            max_title_w = Math.max(1, sc_x - title_x - 1)
            card_buf.put_string(title_x, row_y, VisualWidth.truncate(act.title, max_title_w), fg: is_active ? Color.bright_white : Color.white, bold: is_active)
          end
        end

        # Blit over main buffer
        buffer.blit(card_buf, pal_x, pal_y)
      end
    end
  end
end
