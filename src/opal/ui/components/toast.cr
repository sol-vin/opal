require "../element"
require "../buffer"
require "../../style/color"
require "../../style/border"

module Opal
  module UI
    # Represents a single floating notification message.
    struct Toast
      getter id : String
      getter title : String
      getter message : String
      getter level : Symbol # :info, :success, :warning, :error
      getter duration_ms : Int64
      getter created_at : Time::Instant

      def initialize(
        @title : String,
        @message : String = "",
        @level : Symbol = :info,
        @duration_ms : Int64 = 4000_i64,
        @id : String = Random::Secure.hex(4),
        @created_at : Time::Instant = Time.instant,
      )
      end

      def expired?(now : Time::Instant = Time.instant) : Bool
        (now - @created_at).total_milliseconds >= @duration_ms
      end

      def level_badge : {String, Color}
        case @level
        when :success then {"✔ SUCCESS", Color.green}
        when :warning then {"⚠ WARNING", Color.yellow}
        when :error   then {"✖ ERROR  ", Color.red}
        else               {"ℹ INFO   ", Color.cyan}
        end
      end
    end

    # Manages a collection of toast notifications and renders them over a target buffer.
    class ToastManager
      getter toasts : Array(Toast) = [] of Toast

      def add(title : String, message : String = "", level : Symbol = :info, duration_ms : Int64 = 4000_i64) : Toast
        toast = Toast.new(title: title, message: message, level: level, duration_ms: duration_ms)
        @toasts << toast
        toast
      end

      def clean_expired(now : Time::Instant = Time.instant) : Nil
        @toasts.reject!(&.expired?(now))
      end

      def any? : Bool
        !@toasts.empty?
      end

      def size : Int32
        @toasts.size
      end

      # Renders all active toasts stacked in the top-right corner of the buffer
      def render_overlay(buffer : Buffer, position : Symbol = :top_right, now : Time::Instant = Time.instant) : Nil
        clean_expired(now)
        return if @toasts.empty?

        cur_y = position == :bottom_right ? buffer.height - 1 : 1

        @toasts.reverse_each do |toast|
          badge_label, badge_color = toast.level_badge

          line_width = [VisualWidth.width(toast.title) + 12, VisualWidth.width(toast.message) + 4].max
          card_w = line_width.clamp(28, buffer.width - 4)
          card_h = toast.message.empty? ? 3 : 4

          card_x = buffer.width - card_w - 2
          card_y = position == :bottom_right ? cur_y - card_h : cur_y

          break if card_y < 0 || card_y + card_h > buffer.height

          # Sub-buffer for toast card
          toast_buf = Buffer.new(card_w, card_h)

          # Draw rounded card with solid fill
          b = Border.rounded
          toast_buf.put_string(0, 0, b.top_left, fg: badge_color)
          toast_buf.put_string(1, 0, b.top * (card_w - 2), fg: badge_color)
          toast_buf.put_string(card_w - 1, 0, b.top_right, fg: badge_color)

          (1...(card_h - 1)).each do |y|
            toast_buf.put_string(0, y, b.left, fg: badge_color)
            toast_buf.put_string(1, y, " " * (card_w - 2))
            toast_buf.put_string(card_w - 1, y, b.right, fg: badge_color)
          end

          toast_buf.put_string(0, card_h - 1, b.bottom_left, fg: badge_color)
          toast_buf.put_string(1, card_h - 1, b.bottom * (card_w - 2), fg: badge_color)
          toast_buf.put_string(card_w - 1, card_h - 1, b.bottom_right, fg: badge_color)

          # Header: badge + title
          toast_buf.put_string(2, 1, badge_label, fg: badge_color, bold: true)
          toast_buf.put_string(12, 1, toast.title, fg: Color.white, bold: true, max_width: card_w - 14)

          # Message body if present
          if !toast.message.empty?
            toast_buf.put_string(2, 2, toast.message, fg: Color.bright_black, max_width: card_w - 4)
          end

          buffer.blit(toast_buf, card_x, card_y)

          if position == :bottom_right
            cur_y -= (card_h + 1)
          else
            cur_y += (card_h + 1)
          end
        end
      end
    end
  end
end
