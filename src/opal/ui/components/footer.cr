require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Standardized application bottom footer inspired by Python Textual's Footer.
    # Displays responsive keyboard shortcut badges with key caps and descriptions.
    class Footer < Element
      struct BindingEntry
        getter key : String
        getter description : String
        getter on_press : Proc(Nil)?

        def initialize(@key : String, @description : String, @on_press : Proc(Nil)? = nil)
        end
      end

      property bindings : Array(BindingEntry)
      property bg : Color? = nil
      property key_bg : Color? = nil
      property key_fg : Color? = nil
      property desc_fg : Color? = nil

      # Mouse hit detection for key caps: array of {x, y, w, h, Proc(Nil)}
      @hit_boxes = [] of {Int32, Int32, Int32, Int32, Proc(Nil)}

      def initialize(
        bindings : Array(NamedTuple(key: String, desc: String)) | Array(BindingEntry) = [] of BindingEntry,
      )
        @bindings = case bindings
                    when Array(BindingEntry)
                      bindings
                    else
                      bindings.map { |b| BindingEntry.new(b[:key], b[:desc]) }
                    end
      end

      def add(key : String, description : String, &block : -> Nil) : self
        @bindings << BindingEntry.new(key, description, block)
        self
      end

      def add(key : String, description : String) : self
        @bindings << BindingEntry.new(key, description)
        self
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if event.button == Terminal::MouseButton::Left && event.action == Terminal::MouseAction::Press
          @hit_boxes.each do |bx, by, bw, bh, callback|
            if event.x >= bx && event.x < bx + bw && event.y >= by && event.y < by + bh
              callback.call
              return true
            end
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        @hit_boxes.clear

        th = current_theme
        f_bg = @bg || th.surface
        k_bg = @key_bg || th.primary
        k_fg = @key_fg || th.background
        d_fg = @desc_fg || th.text

        # 1. Fill background bar
        buffer.fill(x, y, width, 1, UI::Cell.new(' ', fg: Color.none, bg: f_bg))

        # 2. Render Bindings
        cur_x = x + 1

        @bindings.each do |b|
          break if cur_x >= x + width - 2

          key_cap = " #{b.key} "
          key_w = VisualWidth.width(key_cap)
          desc_text = " #{b.description} "
          desc_w = VisualWidth.width(desc_text)
          total_item_w = key_w + desc_w + 1

          break if cur_x + key_w >= x + width

          # Key cap badge
          buffer.put_string(cur_x, y, key_cap, fg: k_fg, bg: k_bg, bold: true)

          # Callback registration for mouse clicks
          if cb = b.on_press
            @hit_boxes << {cur_x, y, key_w + desc_w, 1, cb}
          end

          cur_x += key_w

          # Description
          avail_desc = (x + width) - cur_x
          if avail_desc > 0
            buffer.put_string(cur_x, y, desc_text, fg: d_fg, bg: f_bg, max_width: avail_desc)
            cur_x += Math.min(avail_desc, desc_w) + 1
          end
        end
      end
    end
  end
end
