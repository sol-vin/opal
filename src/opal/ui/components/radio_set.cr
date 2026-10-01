require "../control"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Individual radio button component used within a RadioSet.
    class RadioButton
      property label : String
      property? selected : Bool
      property? disabled : Bool

      # Manipulable styling
      property selected_fg : Color? = nil
      property unselected_fg : Color? = nil
      property label_fg : Color? = nil
      property selected_glyph : String? = nil
      property unselected_glyph : String? = nil

      def initialize(
        @label : String,
        @selected : Bool = false,
        @disabled : Bool = false,
      )
      end
    end

    # Group container for mutually exclusive radio choices inspired by Python Textual's RadioSet.
    # Features arrow key navigation, space/enter activation, mouse clicks, and custom glyph swaps.
    class RadioSet < Control
      property buttons : Array(RadioButton)
      property? horizontal : Bool
      property? disabled : Bool
      property on_change : Proc(Int32, String, Nil)?

      # Focused index within the radio set
      property cursor : Int32 = 0

      # Manipulable theme properties
      property active_border_fg : Color? = nil
      property item_spacing : Int32 = 1

      # Hit detection boxes for mouse clicks: array of {x, y, w, h, index}
      @hit_boxes = [] of {Int32, Int32, Int32, Int32, Int32}

      def initialize(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        @horizontal : Bool = false,
        @disabled : Bool = false,
        @on_change : Proc(Int32, String, Nil)? = nil,
      )
        super()
        @buttons = items.map do |it|
          case it
          when RadioButton then it
          else                  RadioButton.new(it.to_s)
          end
        end

        if sel = selected_index
          select_index(sel, fire_callback: false)
        end
      end

      def self.new(
        items : Array(String | RadioButton),
        selected_index : Int32? = 0,
        horizontal : Bool = false,
        disabled : Bool = false,
        &block : (Int32, String) -> Nil
      ) : RadioSet
        new(
          items: items,
          selected_index: selected_index,
          horizontal: horizontal,
          disabled: disabled,
          on_change: block
        )
      end

      def on_change(&block : (Int32, String) -> Nil) : self
        @on_change = block
        self
      end

      # Returns the index of the currently selected button, or nil if none
      def selected_index : Int32?
        @buttons.index(&.selected?)
      end

      # Returns the label of the currently selected button, or nil if none
      def selected_label : String?
        if idx = selected_index
          @buttons[idx].label
        else
          nil
        end
      end

      # Selects radio button at given index, deselecting others
      def select_index(idx : Int32, fire_callback : Bool = true) : self
        return self if @buttons.empty? || @disabled
        clamped_idx = idx.clamp(0, @buttons.size - 1)
        return self if @buttons[clamped_idx].disabled?

        old_idx = selected_index
        @buttons.each_with_index do |btn, i|
          btn.selected = (i == clamped_idx)
        end
        @cursor = clamped_idx

        if fire_callback && old_idx != clamped_idx
          @on_change.try(&.call(clamped_idx, @buttons[clamped_idx].label))
        end
        self
      end

      def select_by_label(label : String) : self
        if idx = @buttons.index { |b| b.label == label }
          select_index(idx)
        end
        self
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @disabled || @buttons.empty?

        case event.name
        when "up"
          move_cursor(-1)
          true
        when "down"
          move_cursor(1)
          true
        when "left"
          move_cursor(-1)
          true
        when "right"
          move_cursor(1)
          true
        when "space", " ", "enter", "return"
          select_index(@cursor)
          true
        else
          false
        end
      end

      private def move_cursor(delta : Int32) : Nil
        return if @buttons.empty?
        new_cursor = (@cursor + delta).clamp(0, @buttons.size - 1)
        @cursor = new_cursor
        # When navigating in a radio set, automatically select the focused button
        select_index(@cursor)
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @disabled

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          @hit_boxes.each do |bx, by, bw, bh, bidx|
            if event.x >= bx && event.x < bx + bw && event.y >= by && event.y < by + bh
              select_index(bidx)
              return true
            end
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        return {0, 0} if @buttons.empty?

        if @horizontal
          total_w = @buttons.map { |b| VisualWidth.width(b.label) + 4 + @item_spacing }.sum
          {Math.min(available_w, total_w), 1}
        else
          max_w = (@buttons.map { |b| VisualWidth.width(b.label) + 4 }.max? || 10)
          {Math.min(available_w, max_w), Math.min(available_h, @buttons.size)}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0 || @buttons.empty?
        @hit_boxes.clear

        th = current_theme
        glyphs = th.glyphs

        c_focus = @active_border_fg || th.primary
        c_sel = th.accent
        c_unsel = th.text_muted
        c_text = @disabled ? th.text_muted : th.text

        cur_x = x
        cur_y = y

        @buttons.each_with_index do |btn, idx|
          break if @horizontal ? (cur_x >= x + width) : (cur_y >= y + height)

          is_cursor = (idx == @cursor) && focused?
          is_sel = btn.selected?
          is_btn_disabled = @disabled || btn.disabled?

          # Choose glyph
          glyph_str = if is_sel
                        btn.selected_glyph || "(●)"
                      else
                        btn.unselected_glyph || "( )"
                      end

          glyph_color = if is_btn_disabled
                          th.text_muted
                        elsif is_sel
                          btn.selected_fg || c_sel
                        else
                          btn.unselected_fg || c_unsel
                        end

          label_color = is_btn_disabled ? th.text_muted : (btn.label_fg || c_text)

          item_w = VisualWidth.width(glyph_str) + 1 + VisualWidth.width(btn.label)
          avail_w = (x + width) - cur_x

          if avail_w > 0
            # Render radio indicator
            buffer.put_string(cur_x, cur_y, glyph_str, fg: glyph_color, bold: is_sel || is_cursor)

            # Render label
            lbl_x = cur_x + VisualWidth.width(glyph_str) + 1
            avail_lbl_w = Math.max(0, avail_w - VisualWidth.width(glyph_str) - 1)
            if avail_lbl_w > 0
              buffer.put_string(lbl_x, cur_y, btn.label, fg: label_color, bold: is_cursor, underline: is_cursor, max_width: avail_lbl_w)
            end

            # Store hit box for mouse selection
            actual_w = Math.min(avail_w, item_w)
            @hit_boxes << {cur_x, cur_y, actual_w, 1, idx}
          end

          if @horizontal
            cur_x += item_w + @item_spacing
          else
            cur_y += 1
          end
        end
      end
    end
  end
end
