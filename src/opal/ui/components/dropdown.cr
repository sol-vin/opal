require "../control"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"

module Opal
  module UI
    enum DropdownStyle
      Classic
      Rounded
      Minimal
      Double
      Pill
      Searchable
    end

    # Interactive Dropdown / Select control. Displays the current selection in a
    # collapsed box and expands into a scrollable popup list on activation.
    # Automatically flips orientation upwards if positioned near the bottom of the screen.
    class Dropdown < Control
      property items : Array(String)
      property selected_index : Int32
      property placeholder : String
      property? expanded : Bool
      property max_visible_items : Int32
      property scroll_offset : Int32
      property on_change : Proc(Int32, String, Nil)?
      property style : DropdownStyle = DropdownStyle::Classic
      property search_query : String = ""

      # Hit test bounds from last render
      @header_x : Int32 = 0
      @header_y : Int32 = 0
      @header_w : Int32 = 0
      @popup_x : Int32 = 0
      @popup_y : Int32 = 0
      @popup_w : Int32 = 0
      @popup_h : Int32 = 0
      @flipped_up : Bool = false

      # Manipulable theme properties and character swaps
      property normal_fg : Color? = nil
      property normal_bg : Color? = nil
      property selected_fg : Color? = nil
      property selected_bg : Color? = nil
      property border_fg : Color? = nil
      property popup_bg : Color? = nil
      property arrow_down_glyph : String? = nil
      property arrow_up_glyph : String? = nil
      property border_style : Border? = nil

      def filtered_items : Array(String)
        if @style == DropdownStyle::Searchable && !@search_query.empty?
          q = @search_query.downcase
          matches = @items.select { |it| it.downcase.includes?(q) }
          matches.empty? ? @items : matches
        else
          @items
        end
      end

      def arrow_glyph : String?
        @arrow_down_glyph
      end

      def arrow_glyph=(g : String?)
        @arrow_down_glyph = g
      end

      def border : Border?
        @border_style
      end

      def border=(b : Border?)
        @border_style = b
      end

      def initialize(
        @items : Array(String),
        @selected_index : Int32 = 0,
        @placeholder : String = "Select...",
        @expanded : Bool = false,
        @max_visible_items : Int32 = 6,
        @on_change : Proc(Int32, String, Nil)? = nil,
        @style : DropdownStyle = DropdownStyle::Classic,
      )
        super()
        @scroll_offset = 0
        clamp_selection
      end

      def on_change(&block : (Int32, String) -> Nil) : self
        @on_change = block
        self
      end

      def self.new(
        items : Array(String),
        selected_index : Int32 = 0,
        placeholder : String = "Select...",
        expanded : Bool = false,
        max_visible_items : Int32 = 6,
        &block : (Int32, String) -> Nil
      ) : Dropdown
        new(
          items: items,
          selected_index: selected_index,
          placeholder: placeholder,
          expanded: expanded,
          max_visible_items: max_visible_items,
          on_change: block
        )
      end

      # Returns the currently selected item label, or placeholder if empty
      def selected_item : String
        @items[@selected_index]? || @placeholder
      end

      # Sets selection by index, updating scroll position and firing callback
      def select_index(index : Int32) : self
        return self if @items.empty?
        old_idx = @selected_index
        @selected_index = index.clamp(0, @items.size - 1)
        adjust_scroll_to_selection
        if old_idx != @selected_index
          @on_change.try(&.call(@selected_index, selected_item))
        end
        self
      end

      # Convenience alias
      def select(index : Int32) : self
        select_index(index)
      end

      # Toggles popup open/closed
      def toggle : self
        @expanded = !@expanded
        adjust_scroll_to_selection if @expanded
        self
      end

      def open : self
        @expanded = true
        adjust_scroll_to_selection
        self
      end

      def close : self
        @expanded = false
        self
      end

      private def clamp_selection : Nil
        return if @items.empty?
        @selected_index = @selected_index.clamp(0, @items.size - 1)
      end

      private def adjust_scroll_to_selection : Nil
        if @selected_index < @scroll_offset
          @scroll_offset = @selected_index
        elsif @selected_index >= (@scroll_offset + @max_visible_items)
          @scroll_offset = @selected_index - @max_visible_items + 1
        end
        max_scroll = Math.max(0, @items.size - @max_visible_items)
        @scroll_offset = @scroll_offset.clamp(0, max_scroll)
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        if @expanded
          case key.name
          when "up"
            select_index(@selected_index - 1)
            true
          when "down"
            select_index(@selected_index + 1)
            true
          when "pageup"
            select_index(@selected_index - @max_visible_items)
            true
          when "pagedown"
            select_index(@selected_index + @max_visible_items)
            true
          when "enter", "return", "space"
            close
            true
          when "escape"
            close
            true
          when "backspace"
            if @style == DropdownStyle::Searchable && !@search_query.empty?
              @search_query = @search_query[0...-1]
              @scroll_offset = 0
              true
            else
              false
            end
          else
            if @style == DropdownStyle::Searchable && (ch = key.char) && ch != '\0' && !key.ctrl? && !key.alt?
              @search_query += ch
              @scroll_offset = 0
              true
            else
              false
            end
          end
        else
          case key.name
          when "enter", "return", "space", "down"
            open
            true
          else
            false
          end
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::Left
          if event.action == Terminal::MouseAction::Press
            # Check header click
            if event.x >= @header_x && event.x < (@header_x + @header_w) && event.y == @header_y
              toggle
              true
              # Check popup list item click
            elsif @expanded && event.x >= @popup_x && event.x < (@popup_x + @popup_w) &&
                  event.y > @popup_y && event.y < (@popup_y + @popup_h - 1)
              search_extra = (@style == DropdownStyle::Searchable) ? 1 : 0
              item_row = event.y - @popup_y - 1 - search_extra
              clicked_idx = @scroll_offset + item_row
              items_to_display = filtered_items
              if clicked_idx >= 0 && clicked_idx < items_to_display.size
                chosen = items_to_display[clicked_idx]
                if actual_idx = @items.index(chosen)
                  select_index(actual_idx)
                end
                close
                true
              else
                false
              end
            else
              # Click outside while open closes dropdown
              if @expanded
                close
                true
              else
                false
              end
            end
          else
            false
          end
        when Terminal::MouseButton::WheelUp
          if @expanded
            @scroll_offset = Math.max(0, @scroll_offset - 1)
            true
          else
            false
          end
        when Terminal::MouseButton::WheelDown
          if @expanded
            max_scroll = Math.max(0, filtered_items.size - @max_visible_items)
            @scroll_offset = Math.min(max_scroll, @scroll_offset + 1)
            true
          else
            false
          end
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        longest_item = (@items.map { |i| VisualWidth.width(i) }.max? || 10)
        min_w = Math.min(16, Math.max(1, available_w))
        box_w = (longest_item + 6).clamp(min_w, Math.max(min_w, available_w))
        {box_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @header_x = x
        @header_y = y
        @header_w = width

        th = current_theme
        glyphs = th.glyphs
        border_c = @border_fg || (focused? ? th.primary : th.border)
        text_c = @normal_fg || (@items.empty? ? th.text_muted : th.text)
        bg_c = @normal_bg || Color.none
        sel_fg = @selected_fg || th.primary
        sel_bg = @selected_bg || th.surface
        pop_bg = @popup_bg || th.background
        b_style = @border_style || (@style == DropdownStyle::Double ? Border.double : (@style == DropdownStyle::Rounded ? Border.rounded : Border.single))

        items_to_display = filtered_items
        search_extra = (@style == DropdownStyle::Searchable) ? 1 : 0
        visible_count = Math.min(items_to_display.size, @max_visible_items)
        popup_total_h = visible_count + 2 + search_extra
        space_below = buffer.height - (y + 1)
        @flipped_up = (space_below < popup_total_h) && (y >= popup_total_h)

        arrow_d = @arrow_down_glyph || glyphs.dropdown_arrow
        arrow_u = @arrow_up_glyph || glyphs.dropdown_arrow_up
        chevron = @expanded ? (@flipped_up ? arrow_u : arrow_d) : arrow_d

        # 2. Render Collapsed Header Box
        inner_w = Math.max(0, width - 4)
        disp_text = VisualWidth.truncate(selected_item, inner_w)
        padding_spaces = Math.max(0, inner_w - VisualWidth.width(disp_text))

        if @style == DropdownStyle::Minimal
          buffer.put_string(x, y, "#{chevron} ", fg: border_c, bold: true)
          buffer.put_string(x + 2, y, disp_text, fg: text_c, bold: focused?, underline: true)
        elsif @style == DropdownStyle::Classic
          buffer.put_string(x, y, "[ ", fg: border_c, bg: bg_c)
          buffer.put_string(x + 2, y, disp_text, fg: text_c, bg: bg_c, bold: focused?)
          buffer.put_string(x + 2 + VisualWidth.width(disp_text), y, " " * padding_spaces, bg: bg_c)
          buffer.put_string(x + width - 2, y, "#{chevron} ]", fg: border_c, bg: bg_c, bold: true)
        else
          lb, rb = case @style
                   when DropdownStyle::Rounded then {"╭─ ", " ─╮"}
                   when DropdownStyle::Pill    then {"( ", " )"}
                   when DropdownStyle::Double  then {"╔═ ", " ═╗"}
                   else                             {"[ ", " ]"}
                   end

          buffer.put_string(x, y, lb, fg: border_c, bg: bg_c)
          buffer.put_string(x + lb.size, y, disp_text, fg: text_c, bg: bg_c, bold: focused?)
          rem_pad = Math.max(0, width - lb.size - rb.size - VisualWidth.width(disp_text))
          buffer.put_string(x + lb.size + VisualWidth.width(disp_text), y, " " * rem_pad, bg: bg_c)
          buffer.put_string(x + width - rb.size, y, "#{chevron}#{rb[1..-1]}", fg: border_c, bg: bg_c, bold: true)
        end

        # 3. Render Expanded Popup List if opened
        if @expanded && !items_to_display.empty?
          @popup_x = x
          @popup_y = @flipped_up ? (y - popup_total_h) : (y + 1)
          @popup_w = width
          @popup_h = popup_total_h

          # Fill popup solid background
          Graphics::Primitives2D.fill_rect(buffer, @popup_x, @popup_y, @popup_w, @popup_h, ' ', fg: Color.none, bg: pop_bg)

          # Draw popup box
          buffer.put_string(@popup_x, @popup_y, b_style.top_left, fg: border_c, bg: pop_bg)
          buffer.put_string(@popup_x + 1, @popup_y, b_style.top_segment(@popup_w - 2), fg: border_c, bg: pop_bg)
          buffer.put_string(@popup_x + @popup_w - 1, @popup_y, b_style.top_right, fg: border_c, bg: pop_bg)

          # Search bar if searchable
          if @style == DropdownStyle::Searchable
            search_str = "🔍 #{@search_query}_"
            buffer.put_char(@popup_x, @popup_y + 1, b_style.left_char(0), fg: border_c, bg: pop_bg)
            buffer.put_string(@popup_x + 1, @popup_y + 1, search_str, fg: Color.hex("#00f2fe"), bg: pop_bg, bold: true)
            buffer.put_char(@popup_x + @popup_w - 1, @popup_y + 1, b_style.right_char(0), fg: border_c, bg: pop_bg)
          end

          (0...visible_count).each do |row_idx|
            item_idx = @scroll_offset + row_idx
            cur_y = @popup_y + 1 + search_extra + row_idx
            item_text = items_to_display[item_idx]? || ""
            is_sel = (item_text == selected_item)

            buffer.put_char(@popup_x, cur_y, b_style.left_char(row_idx + search_extra), fg: border_c, bg: pop_bg)

            # Fill item row
            row_inner_w = @popup_w - 2
            trunc_item = VisualWidth.truncate(item_text, row_inner_w - 2)
            row_pad = Math.max(0, row_inner_w - 2 - VisualWidth.width(trunc_item))

            if is_sel
              buffer.put_string(@popup_x + 1, cur_y, " #{trunc_item}#{" " * row_pad} ", fg: sel_fg, bg: sel_bg, bold: true)
            else
              buffer.put_string(@popup_x + 1, cur_y, " #{trunc_item}#{" " * row_pad} ", fg: text_c, bg: pop_bg)
            end

            buffer.put_char(@popup_x + @popup_w - 1, cur_y, b_style.right_char(row_idx + search_extra), fg: border_c, bg: pop_bg)
          end

          # Bottom border
          bottom_y = @popup_y + popup_total_h - 1
          buffer.put_string(@popup_x, bottom_y, b_style.bottom_left, fg: border_c, bg: pop_bg)
          buffer.put_string(@popup_x + 1, bottom_y, b_style.bottom_segment(@popup_w - 2), fg: border_c, bg: pop_bg)
          buffer.put_string(@popup_x + @popup_w - 1, bottom_y, b_style.bottom_right, fg: border_c, bg: pop_bg)
        end
      end
    end
  end
end
