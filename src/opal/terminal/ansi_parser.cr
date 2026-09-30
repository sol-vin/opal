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
        if name_lower == base_name ||
           (name_lower == "escape" && base_name == "esc") ||
           (name_lower == "esc" && base_name == "escape") ||
           (name_lower == "page_up" && base_name == "pageup") ||
           (name_lower == "pageup" && base_name == "page_up") ||
           (name_lower == "page_down" && base_name == "pagedown") ||
           (name_lower == "pagedown" && base_name == "page_down")
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

        # rxvt Shift+Arrow sequences: \e[a (Shift+Up), \e[b (Shift+Down), \e[c (Shift+Right), \e[d (Shift+Left)
        case body
        when "a" then return KeyEvent.new("up", shift: true)
        when "b" then return KeyEvent.new("down", shift: true)
        when "c" then return KeyEvent.new("right", shift: true)
        when "d" then return KeyEvent.new("left", shift: true)
        end

        # Modified sequences like \e[1;2C (Shift+Right), \e[1;5A (Ctrl+Up), or \e[2C (Shift+Right)
        if body =~ /^(\d+)(?:;(\d+))?([A-Za-z~])$/
          first_num = $1.to_i? || 1
          second_num = $2?.try(&.to_i?)
          key_code = $3.upcase

          modifier = second_num || first_num
          code = second_num ? first_num : 1

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

      SGR_MOUSE_REGEX = /\A\e\[<(\d+);(\d+);(\d+)([Mm])/

      # Parses an SGR mouse tracking sequence: \e[<b;x;yM or \e[<b;x;ym
      def self.parse_mouse(input : String) : MouseEvent?
        return nil unless input.starts_with?("\e[<")
        if md = input.match(SGR_MOUSE_REGEX)
          btn_code = md[1].to_i? || 0
          x = md[2].to_i? || 1
          y = md[3].to_i? || 1
          action_char = md[4][0]

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
        else
          nil
        end
      end

      # Parses an entire raw input chunk and extracts all contained KeyEvents and MouseEvents
      def self.parse_all(input : String) : Array(KeyEvent | MouseEvent)
        events = [] of KeyEvent | MouseEvent
        return events if input.empty?

        i = 0
        bytes = input.to_slice
        len = bytes.size

        while i < len
          b = bytes[i]
          if b == 27 # ESC
            remaining = String.new(bytes[i, len - i])

            # 1. SGR Mouse: \e[<btn;x;y(M|m)
            if remaining.starts_with?("\e[<")
              if md = remaining.match(SGR_MOUSE_REGEX)
                if mouse_ev = parse_mouse(md[0])
                  events << mouse_ev
                  i += md[0].bytesize
                  next
                end
              end
            end

            # 2. SS3 format: \eOP to \eOS (F1-F4)
            if remaining.starts_with?("\eO") && remaining.bytesize >= 3
              sub = remaining[0, 3]
              if key_ev = parse_key(sub)
                events << key_ev
                i += 3
                next
              end
            end

            # 3. CSI sequence: \e[ ... <terminator>
            if remaining.starts_with?("\e[")
              seq_len = 2
              while (i + seq_len) < len
                term_byte = bytes[i + seq_len]
                seq_len += 1
                if term_byte >= 0x40 && term_byte <= 0x7E
                  break
                end
              end
              sub = String.new(bytes[i, seq_len])
              if key_ev = parse_key(sub)
                events << key_ev
              end
              i += seq_len
              next
            end

            # 4. Alt + key: \e<char>
            if remaining.bytesize >= 2 && remaining[1] != '[' && remaining[1] != 'O'
              first_char = remaining.chars[1]
              sub = remaining[0, 1 + first_char.bytesize]
              if key_ev = parse_key(sub)
                events << key_ev
              end
              i += 1 + first_char.bytesize
              next
            end

            # 5. Standalone ESC
            events << KeyEvent.new("escape")
            i += 1
            next
          end

          # Control characters
          case b
          when 13 # \r
            if i + 1 < len && bytes[i + 1] == 10
              events << KeyEvent.new("enter", '\n')
              i += 2
            else
              events << KeyEvent.new("enter", '\n')
              i += 1
            end
            next
          when 10 # \n
            events << KeyEvent.new("enter", '\n')
            i += 1
            next
          when 9 # \t
            events << KeyEvent.new("tab", '\t')
            i += 1
            next
          when 127, 8 # Backspace
            events << KeyEvent.new("backspace")
            i += 1
            next
          when 1..26 # Ctrl+A .. Ctrl+Z
            char = ('a'.ord + b - 1).chr
            events << KeyEvent.new(char.to_s, char, ctrl: true)
            i += 1
            next
          end

          # Regular UTF-8 character
          sub = String.new(bytes[i, len - i])
          first_char = sub.chars.first
          events << KeyEvent.new(first_char.to_s, first_char)
          i += first_char.bytesize
        end

        events
      end
    end
  end
end
