require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"

module Opal
  module UI
    # A centered floating modal dialog component with backdrop dimming and button choices.
    class Modal < Element
      getter title : String
      getter message : String
      getter buttons : Array(String)
      property selected_button : Int32
      getter border_fg : Color
      getter title_fg : Color
      getter button_fg : Color
      getter selected_fg : Color
      getter selected_bg : Color
      getter dim_backdrop : Bool

      def initialize(
        @title : String,
        @message : String,
        @buttons : Array(String) = ["OK"],
        @selected_button : Int32 = 0,
        border_fg : Color | Symbol | String = :cyan,
        title_fg : Color | Symbol | String = :bright_white,
        button_fg : Color | Symbol | String = :white,
        selected_fg : Color | Symbol | String = :black,
        selected_bg : Color | Symbol | String = :cyan,
        @dim_backdrop : Bool = true,
      )
        @border_fg = Color.from(border_fg)
        @title_fg = Color.from(title_fg)
        @button_fg = Color.from(button_fg)
        @selected_fg = Color.from(selected_fg)
        @selected_bg = Color.from(selected_bg)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        msg_lines = @message.split('\n')
        msg_w = (msg_lines.map { |l| VisualWidth.width(l) }.max? || 0)
        btn_w = @buttons.map { |b| VisualWidth.width(b) + 4 }.sum + (@buttons.size - 1) * 2
        content_w = [VisualWidth.width(@title) + 4, msg_w, btn_w].max
        modal_w = (content_w + 6).clamp(30, available_w)
        modal_h = (msg_lines.size + 6).clamp(6, available_h)
        {modal_w, modal_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # Dim background if requested
        buffer.dim_all if @dim_backdrop

        modal_w, modal_h = preferred_size(width, height)
        modal_x = x + (width - modal_w) // 2
        modal_y = y + (height - modal_h) // 2

        # Create isolated sub-buffer for modal card
        modal_buf = Buffer.new(modal_w, modal_h)

        # Draw box border
        b = Border.rounded
        # Top border
        modal_buf.put_string(0, 0, b.top_left, fg: @border_fg)
        modal_buf.put_string(1, 0, b.top * (modal_w - 2), fg: @border_fg)
        modal_buf.put_string(modal_w - 1, 0, b.top_right, fg: @border_fg)

        # Side borders & solid background fill
        (1...(modal_h - 1)).each do |cur_y|
          modal_buf.put_string(0, cur_y, b.left, fg: @border_fg)
          modal_buf.put_string(1, cur_y, " " * (modal_w - 2))
          modal_buf.put_string(modal_w - 1, cur_y, b.right, fg: @border_fg)
        end

        # Bottom border
        modal_buf.put_string(0, modal_h - 1, b.bottom_left, fg: @border_fg)
        modal_buf.put_string(1, modal_h - 1, b.bottom * (modal_w - 2), fg: @border_fg)
        modal_buf.put_string(modal_w - 1, modal_h - 1, b.bottom_right, fg: @border_fg)

        # Title
        title_str = " #{@title} "
        modal_buf.put_string(2, 0, title_str, fg: @title_fg, bold: true)

        # Message text
        msg_lines = @message.split('\n')
        msg_lines.each_with_index do |line, idx|
          break if idx >= modal_h - 4
          modal_buf.put_string(3, 2 + idx, line, fg: @button_fg)
        end

        # Buttons at bottom
        btn_y = modal_h - 2
        cur_btn_x = 3
        @buttons.each_with_index do |btn, idx|
          is_active = (idx == @selected_button)
          btn_text = "[ #{btn} ]"
          if is_active
            modal_buf.put_string(cur_btn_x, btn_y, btn_text, fg: @selected_fg, bg: @selected_bg, bold: true)
          else
            modal_buf.put_string(cur_btn_x, btn_y, btn_text, fg: @button_fg)
          end
          cur_btn_x += VisualWidth.width(btn_text) + 2
        end

        # Blit modal over target buffer
        buffer.blit(modal_buf, modal_x, modal_y)
      end
    end
  end
end
