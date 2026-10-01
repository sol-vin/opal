require "../element"
require "../../style/color"
require "../../style/visual_width"

module Opal
  module UI
    # Animated loading spinner indicator inspired by Python Textual's LoadingIndicator.
    # Supports multiple animation styles (:dots, :pulse, :bars, :orbit), customizable labels,
    # and theme colors.
    class LoadingIndicator < Element
      property label : String?
      property style : Symbol
      property fg : Color? = nil
      property label_fg : Color? = nil
      property frame : UInt64 = 0_u64

      SPINNERS = {
        dots:  ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
        pulse: ["░", "▒", "▓", "█", "▓", "▒"],
        bars:  [" ", "▃", "▄", "▅", "▆", "▇", "█", "▇", "▆", "▅", "▄", "▃"],
        orbit: ["◐", "◓", "◑", "◒"],
      }

      def initialize(
        @label : String? = nil,
        @style : Symbol = :dots,
        fg : Color | Symbol | String | Nil = nil,
        label_fg : Color | Symbol | String | Nil = nil,
      )
        @fg = fg ? Color.from(fg) : nil
        @label_fg = label_fg ? Color.from(label_fg) : nil
      end

      # Advances the animation frame
      def tick : self
        @frame &+= 1_u64
        self
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        lbl_w = @label ? (VisualWidth.width(@label.not_nil!) + 2) : 0
        {Math.min(available_w, 2 + lbl_w), 1}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        th = current_theme
        spinner_fg = @fg || th.accent
        lbl_fg = @label_fg || th.text

        frames = SPINNERS[@style]? || SPINNERS[:dots]
        idx = (@frame % frames.size).to_i
        glyph = frames[idx]

        # Render spinner glyph
        buffer.put_string(x, y, glyph, fg: spinner_fg, bold: true)

        # Render label
        if lbl = @label
          avail_lbl = width - 2
          if avail_lbl > 0
            buffer.put_string(x + 2, y, lbl, fg: lbl_fg, max_width: avail_lbl)
          end
        end
      end
    end
  end
end
