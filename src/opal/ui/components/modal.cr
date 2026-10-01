require "../control"
require "../buffer"
require "../../style/color"
require "../../style/border"

module Opal
  module UI
    record ModalButtonHitBox, index : Int32, x : Int32, y : Int32, width : Int32, height : Int32

    # A centered floating modal dialog component with backdrop dimming and button choices.
    class Modal < Control
      property title : String
      property message : String
      property buttons : Array(String)
      property selected_button : Int32
      property border_fg : Color?
      property title_fg : Color?
      property button_fg : Color?
      property selected_fg : Color?
      property selected_bg : Color?
      property bg : Color?
      property border_style : Border?
      property dim_backdrop : Bool
      property on_submit : Proc(Int32, Nil)? = nil
      property? dismissed : Bool = false

      @button_hit_boxes : Array(ModalButtonHitBox) = [] of ModalButtonHitBox

      def initialize(
        @title : String,
        @message : String,
        @buttons : Array(String) = ["OK"],
        @selected_button : Int32 = 0,
        border_fg : Color | Symbol | String | Nil = nil,
        title_fg : Color | Symbol | String | Nil = nil,
        button_fg : Color | Symbol | String | Nil = nil,
        selected_fg : Color | Symbol | String | Nil = nil,
        selected_bg : Color | Symbol | String | Nil = nil,
        bg : Color | Symbol | String | Nil = nil,
        border_style : Border | Symbol | String | Nil = nil,
        @dim_backdrop : Bool = true,
        @on_submit : Proc(Int32, Nil)? = nil,
      )
        super()
        @border_fg = border_fg ? Color.from(border_fg) : nil
        @title_fg = title_fg ? Color.from(title_fg) : nil
        @button_fg = button_fg ? Color.from(button_fg) : nil
        @selected_fg = selected_fg ? Color.from(selected_fg) : nil
        @selected_bg = selected_bg ? Color.from(selected_bg) : nil
        @bg = bg ? Color.from(bg) : nil
        @border_style = border_style ? Border.from(border_style) : nil
      end

      def self.new(
        title : String,
        message : String,
        buttons : Array(String) = ["OK"],
        selected_button : Int32 = 0,
        border_fg : Color | Symbol | String | Nil = nil,
        title_fg : Color | Symbol | String | Nil = nil,
        button_fg : Color | Symbol | String | Nil = nil,
        selected_fg : Color | Symbol | String | Nil = nil,
        selected_bg : Color | Symbol | String | Nil = nil,
        bg : Color | Symbol | String | Nil = nil,
        border_style : Border | Symbol | String | Nil = nil,
        dim_backdrop : Bool = true,
        &block : Int32 -> Nil
      ) : Modal
        new(
          title: title,
          message: message,
          buttons: buttons,
          selected_button: selected_button,
          border_fg: border_fg,
          title_fg: title_fg,
          button_fg: button_fg,
          selected_fg: selected_fg,
          selected_bg: selected_bg,
          bg: bg,
          border_style: border_style,
          dim_backdrop: dim_backdrop,
          on_submit: block,
        )
      end

      def on_submit(&block : Int32 -> Nil) : self
        @on_submit = block
        self
      end

      def submit_selected : Nil
        @on_submit.try(&.call(@selected_button))
      end

      def dismiss : Nil
        @dismissed = true
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        msg_lines = @message.split('\n')
        msg_w = (msg_lines.map { |l| VisualWidth.width(l) }.max? || 0)
        btn_w = @buttons.map { |b| VisualWidth.width(b) + 4 }.sum + (@buttons.size - 1) * 2
        content_w = [VisualWidth.width(@title) + 4, msg_w, btn_w].max
        modal_w = (content_w + 6).clamp(Math.min(30, available_w), available_w)
        modal_h = (msg_lines.size + 6).clamp(Math.min(6, available_h), available_h)
        {modal_w, modal_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        # Dim background if requested
        buffer.dim_all if @dim_backdrop

        modal_w, modal_h = preferred_size(width, height)
        modal_x = x + (width - modal_w) // 2
        modal_y = y + (height - modal_h) // 2

        # Create isolated sub-buffer for modal card
        modal_buf = Buffer.new(modal_w, modal_h)

        th = current_theme
        b_fg = @border_fg || th.primary
        t_fg = @title_fg || th.accent
        btn_fg = @button_fg || th.text
        s_fg = @selected_fg || th.background
        s_bg = @selected_bg || th.accent
        card_bg = @bg || th.background
        b = @border_style || Border.rounded

        # Fill background
        Graphics::Primitives2D.fill_rect(modal_buf, 0, 0, modal_w, modal_h, ' ', fg: Color.none, bg: card_bg)

        # Draw box border with pattern support
        modal_buf.put_string(0, 0, b.top_left, fg: b_fg, bg: card_bg)
        modal_buf.put_string(1, 0, b.top_segment(modal_w - 2), fg: b_fg, bg: card_bg)
        modal_buf.put_string(modal_w - 1, 0, b.top_right, fg: b_fg, bg: card_bg)

        # Side borders
        (1...(modal_h - 1)).each do |cur_y|
          modal_buf.put_char(0, cur_y, b.left_char(cur_y - 1), fg: b_fg, bg: card_bg)
          modal_buf.put_char(modal_w - 1, cur_y, b.right_char(cur_y - 1), fg: b_fg, bg: card_bg)
        end

        # Bottom border
        modal_buf.put_string(0, modal_h - 1, b.bottom_left, fg: b_fg, bg: card_bg)
        modal_buf.put_string(1, modal_h - 1, b.bottom_segment(modal_w - 2), fg: b_fg, bg: card_bg)
        modal_buf.put_string(modal_w - 1, modal_h - 1, b.bottom_right, fg: b_fg, bg: card_bg)

        # Title safely clamped
        avail_t = Math.max(0, modal_w - 4)
        if avail_t > 0
          modal_buf.put_string(2, 0, " #{@title} ", fg: t_fg, bg: card_bg, bold: true, max_width: avail_t)
        end

        # Message text safely clamped
        msg_lines = @message.split('\n')
        msg_lines.each_with_index do |line, idx|
          break if idx >= modal_h - 4
          modal_buf.put_string(3, 2 + idx, line, fg: btn_fg, bg: card_bg, max_width: modal_w - 6)
        end

        # Buttons at bottom
        @button_hit_boxes.clear
        btn_y = modal_h - 2
        cur_btn_x = 3
        @buttons.each_with_index do |btn, idx|
          break if cur_btn_x >= modal_w - 3
          is_active = (idx == @selected_button)
          btn_text = "[ #{btn} ]"
          btn_w = VisualWidth.width(btn_text)
          avail_btn_w = Math.max(0, (modal_w - 2) - cur_btn_x)
          @button_hit_boxes << ModalButtonHitBox.new(idx, modal_x + cur_btn_x, modal_y + btn_y, Math.min(btn_w, avail_btn_w), 1)
          if is_active
            modal_buf.put_string(cur_btn_x, btn_y, btn_text, fg: s_fg, bg: s_bg, bold: true, max_width: avail_btn_w)
          else
            modal_buf.put_string(cur_btn_x, btn_y, btn_text, fg: btn_fg, bg: card_bg, max_width: avail_btn_w)
          end
          cur_btn_x += btn_w + 2
        end

        # Blit modal over target buffer
        buffer.blit(modal_buf, modal_x, modal_y)
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        return false if @dismissed

        case event.name
        when "left", "h", "up"
          @selected_button = Math.max(0, @selected_button - 1)
          true
        when "right", "l", "down", "tab"
          @selected_button = Math.min(@buttons.size - 1, @selected_button + 1)
          true
        when "enter", "return", "space", " "
          submit_selected
          true
        when "escape"
          dismiss
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        return false if @dismissed

        case event.button
        when Terminal::MouseButton::WheelUp
          @selected_button = Math.max(0, @selected_button - 1)
          return true
        when Terminal::MouseButton::WheelDown
          @selected_button = Math.min(@buttons.size - 1, @selected_button + 1)
          return true
        end

        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          @button_hit_boxes.each do |hit|
            if event.x >= hit.x && event.x < hit.x + hit.width && event.y == hit.y
              @selected_button = hit.index
              submit_selected
              return true
            end
          end
        end

        false
      end
    end
  end
end
