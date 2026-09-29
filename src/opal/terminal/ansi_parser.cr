module Opal
  module Terminal
    # Represents a keyboard input event with modifier details.
    struct KeyEvent
      getter name : String
      getter char : Char?
      getter? ctrl : Bool
      getter? alt : Bool
      getter? shift : Bool

      def initialize(
        @name : String,
        @char : Char? = nil,
        @ctrl : Bool = false,
        @alt : Bool = false,
        @shift : Bool = false,
      )
      end

      # Convenience helper: returns whether this event matches a string key description
      # like "ctrl+c", "enter", "q", "up", "esc".
      def matches?(key_desc : String) : Bool
        parts = key_desc.downcase.split('+').map(&.strip)
        expected_ctrl = parts.includes?("ctrl")
        expected_alt = parts.includes?("alt") || parts.includes?("meta")
        expected_shift = parts.includes?("shift")
        base_name = parts.reject { |p| ["ctrl", "alt", "meta", "shift"].includes?(p) }.first? || ""

        return false unless @ctrl == expected_ctrl
        return false unless @alt == expected_alt
        return false unless @shift == expected_shift

        name_lower = @name.downcase
        if name_lower == base_name || (name_lower == "escape" && base_name == "esc") || (name_lower == "esc" && base_name == "escape")
          true
        elsif @char && @char.to_s.downcase == base_name
          true
        else
          false
        end
      end

      def to_s(io : IO) : Nil
        parts = [] of String
        parts << "Ctrl" if @ctrl
        parts << "Alt" if @alt
        parts << "Shift" if @shift
        parts << @name
        io << parts.join("+")
      end
    end

    alias Key = KeyEvent

    # Mouse button actions
    enum MouseButton
      Left
      Middle
      Right
      WheelUp
      WheelDown
      None
    end

    enum MouseAction
      Press
      Release
      Motion
    end

    # Represents a mouse tracking event in the terminal.
    struct MouseEvent
      getter x : Int32
      getter y : Int32
      getter button : MouseButton
      getter action : MouseAction
      getter? ctrl : Bool
      getter? alt : Bool
      getter? shift : Bool

      def initialize(
        @x : Int32,
        @y : Int32,
        @button : MouseButton,
        @action : MouseAction,
        @ctrl : Bool = false,
        @alt : Bool = false,
        @shift : Bool = false,
      )
      end
    end

    alias ANSIParser = AnsiParser

    # Decoder that turns raw byte chunks and ANSI escape sequences into structured events.
    class AnsiParser
      # Parses input bytes/string into a list of KeyEvents or MouseEvents.
      def self.parse_key(input : String) : KeyEvent?
        return nil if input.empty?

        # Single byte control keys
        first_byte = input.byte_at(0)

        # Handle Enter, Tab, Backspace, Escape
        case first_byte
        when 13 # \r
          return KeyEvent.new("enter", '\n')
        when 10 # \n
          return KeyEvent.new("enter", '\n')
        when 9 # \t
          return KeyEvent.new("tab", '\t')
        when 127, 8 # Backspace / Delete
          return KeyEvent.new("backspace")
        when 27 # Escape or Escape Sequence
          if input.size == 1
            return KeyEvent.new("escape")
          end
          return parse_escape_sequence(input)
        when 1..26
          # Ctrl+A (1) through Ctrl+Z (26)
          # Note: Ctrl+C is 3, Ctrl+D is 4
          char = ('a'.ord + first_byte - 1).chr
          return KeyEvent.new(char.to_s, char, ctrl: true)
        end

        # Standard unicode character
        first_char = input.chars.first
        KeyEvent.new(first_char.to_s, first_char)
      end

      # Parses an escape sequence starting with \e
      private def self.parse_escape_sequence(seq : String) : KeyEvent?
        return KeyEvent.new("escape") if seq.size < 2

        # Alt + key: \e<char>
        if seq.size == 2 && seq[1] != '[' && seq[1] != 'O'
          ch = seq[1]
          return KeyEvent.new(ch.to_s, ch, alt: true)
        end

        # SS3 format: \eOP to \eOS (F1-F4)
        if seq.starts_with?("\eO") && seq.size >= 3
          case seq[2]
          when 'P' then return KeyEvent.new("f1")
          when 'Q' then return KeyEvent.new("f2")
          when 'R' then return KeyEvent.new("f3")
          when 'S' then return KeyEvent.new("f4")
          end
        end

        return nil unless seq.starts_with?("\e[")
        body = seq[2..]

        # SGR Mouse: \e[<btn;x;yM or \e[<btn;x;ym (Handled in parse_mouse)
        return nil if body.starts_with?('<')

        # Check for simple cursor keys
        case body
        when "A" then return KeyEvent.new("up")
        when "B" then return KeyEvent.new("down")
        when "C" then return KeyEvent.new("right")
        when "D" then return KeyEvent.new("left")
        when "H" then return KeyEvent.new("home")
        when "F" then return KeyEvent.new("end")
        when "Z" then return KeyEvent.new("backtab", shift: true)
        end

        # Check for tilde sequences \e[<n>~
        if body.ends_with?('~')
          if num = body[0...-1].to_i?
            case num
            when 1 then return KeyEvent.new("home")
            when 2 then return KeyEvent.new("insert")
            when 3 then return KeyEvent.new("delete")
            when 4 then return KeyEvent.new("end")
            when 5 then return KeyEvent.new("page_up")
            when 6 then return KeyEvent.new("page_down")
            when 7 then return KeyEvent.new("home")
            when 8 then return KeyEvent.new("end")
            when 11, 12, 13, 14, 15 then return KeyEvent.new("f#{num - 10}") # F1..F5
            when 17 then return KeyEvent.new("f6")
            when 18 then return KeyEvent.new("f7")
            when 19 then return KeyEvent.new("f8")
            when 20 then return KeyEvent.new("f9")
            when 21 then return KeyEvent.new("f10")
            when 23 then return KeyEvent.new("f11")
            when 24 then return KeyEvent.new("f12")
            end
          end
        end

        # Modified sequences like \e[1;5A (Ctrl+Up)
        if body =~ /^(\d+);(\d+)([A-Z~])$/
          code = $1.to_i? || 1
          modifier = $2.to_i? || 1
          key_code = $3

          ctrl = (modifier - 1) & 4 != 0
          alt = (modifier - 1) & 2 != 0
          shift = (modifier - 1) & 1 != 0

          key_name = case key_code
                     when "A" then "up"
                     when "B" then "down"
                     when "C" then "right"
                     when "D" then "left"
                     when "H" then "home"
                     when "F" then "end"
                     when "~"
                       case code
                       when 2 then "insert"
                       when 3 then "delete"
                       when 5 then "page_up"
                       when 6 then "page_down"
                       else        "unknown"
                       end
                     else "unknown"
                     end

          return KeyEvent.new(key_name, ctrl: ctrl, alt: alt, shift: shift)
        end

        KeyEvent.new("escape")
      end

      # Parses an SGR mouse tracking sequence: \e[<b;x;yM or \e[<b;x;ym
      def self.parse_mouse(input : String) : MouseEvent?
        return nil unless input.starts_with?("\e[<")
        action_char = input[-1]?
        return nil unless action_char == 'M' || action_char == 'm'

        inner = input[3...-1]
        parts = inner.split(';')
        return nil if parts.size < 3

        btn_code = parts[0].to_i? || 0
        x = parts[1].to_i? || 1
        y = parts[2].to_i? || 1

        ctrl = (btn_code & 16) != 0
        alt = (btn_code & 8) != 0
        shift = (btn_code & 4) != 0
        is_motion = (btn_code & 32) != 0

        action = if action_char == 'm'
                   MouseAction::Release
                 elsif is_motion
                   MouseAction::Motion
                 else
                   MouseAction::Press
                 end

        button = case btn_code & 67
                 when  0 then MouseButton::Left
                 when  1 then MouseButton::Middle
                 when  2 then MouseButton::Right
                 when 64 then MouseButton::WheelUp
                 when 65 then MouseButton::WheelDown
                 else         MouseButton::None
                 end

        MouseEvent.new(
          x: x,
          y: y,
          button: button,
          action: action,
          ctrl: ctrl,
          alt: alt,
          shift: shift
        )
      end
    end
  end
end
