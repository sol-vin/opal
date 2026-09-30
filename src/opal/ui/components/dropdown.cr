require "../control"
require "../../style/color"
require "../../style/border"
require "../../style/visual_width"

module Opal
  module UI
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

      # Hit test bounds from last render
      @header_x : Int32 = 0
      @header_y : Int32 = 0
      @header_w : Int32 = 0
      @popup_x : Int32 = 0
      @popup_y : Int32 = 0
      @popup_w : Int32 = 0
      @popup_h : Int32 = 0
      @flipped_up : Bool = false

      def initialize(
        @items : Array(String),
        @selected_index : Int32 = 0,
        @placeholder : String = "Select...",
        @expanded : Bool = false,
        @max_visible_items : Int32 = 6,
        @on_change : Proc(Int32, String, Nil)? = nil,
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
          else
            false
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
              item_row = event.y - @popup_y - 1
              clicked_idx = @scroll_offset + item_row
              if clicked_idx >= 0 && clicked_idx < @items.size
                select_index(clicked_idx)
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
            max_scroll = Math.max(0, @items.size - @max_visible_items)
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
        box_w = (longest_item + 6).clamp(16, available_w)
        {box_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @header_x = x
        @header_y = y
        @header_w = width

        theme = Theme.current
        border_c = focused? ? theme.primary : theme.border
        text_c = @items.empty? ? theme.text_muted : theme.text

        # 1. Determine popup orientation (auto-flip if near screen bottom)
        visible_count = Math.min(@items.size, @max_visible_items)
        popup_total_h = visible_count + 2
        space_below = buffer.height - (y + 1)
        @flipped_up = (space_below < popup_total_h) && (y >= popup_total_h)

        chevron = @expanded ? (@flipped_up ? "▲" : "▼") : "▼"

        # 2. Render Collapsed Header Box
        inner_w = Math.max(0, width - 4)
        disp_text = VisualWidth.truncate(selected_item, inner_w)
        padding_spaces = Math.max(0, inner_w - VisualWidth.width(disp_text))

        buffer.put_string(x, y, "[ ", fg: border_c)
        buffer.put_string(x + 2, y, disp_text, fg: text_c, bold: focused?)
        buffer.put_string(x + 2 + VisualWidth.width(disp_text), y, " " * padding_spaces)
        buffer.put_string(x + width - 2, y, "#{chevron} ]", fg: border_c, bold: true)

        # 3. Render Expanded Popup List if opened
        if @expanded && !@items.empty?
          @popup_x = x
          @popup_y = @flipped_up ? (y - popup_total_h) : (y + 1)
          @popup_w = width
          @popup_h = popup_total_h

          # Draw popup box
          b = Border.single
          buffer.put_string(@popup_x, @popup_y, b.top_left, fg: border_c)
          buffer.put_string(@popup_x + 1, @popup_y, b.top * (@popup_w - 2), fg: border_c)
          buffer.put_string(@popup_x + @popup_w - 1, @popup_y, b.top_right, fg: border_c)

          (0...visible_count).each do |row_idx|
            item_idx = @scroll_offset + row_idx
            cur_y = @popup_y + 1 + row_idx
            item_text = @items[item_idx]? || ""
            is_sel = (item_idx == @selected_index)

            buffer.put_string(@popup_x, cur_y, b.left, fg: border_c)

            # Fill item row
            row_inner_w = @popup_w - 2
            trunc_item = VisualWidth.truncate(item_text, row_inner_w - 2)
            row_pad = Math.max(0, row_inner_w - 2 - VisualWidth.width(trunc_item))

            if is_sel
              buffer.put_string(@popup_x + 1, cur_y, " #{trunc_item}#{" " * row_pad} ", fg: theme.primary, bg: theme.surface, bold: true)
            else
              buffer.put_string(@popup_x + 1, cur_y, " #{trunc_item}#{" " * row_pad} ", fg: theme.text)
            end

            buffer.put_string(@popup_x + @popup_w - 1, cur_y, b.right, fg: border_c)
          end

          # Bottom border
          bottom_y = @popup_y + popup_total_h - 1
          buffer.put_string(@popup_x, bottom_y, b.bottom_left, fg: border_c)
          buffer.put_string(@popup_x + 1, bottom_y, b.bottom * (@popup_w - 2), fg: border_c)
          buffer.put_string(@popup_x + @popup_w - 1, bottom_y, b.bottom_right, fg: border_c)
        end
      end
    end
  end
end
