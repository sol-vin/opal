require "../terminal"

module Opal
  module TEA
    # Base interface for all messages dispatched in The Elm Architecture loop.
    abstract class Msg
    end

    # Dispatched when a keyboard key is pressed.
    class KeyMsg < Msg
      getter key : String
      getter char : Char?
      getter? ctrl : Bool
      getter? alt : Bool
      getter? shift : Bool

      def initialize(
        @key : String,
        @char : Char? = nil,
        @ctrl : Bool = false,
        @alt : Bool = false,
        @shift : Bool = false,
      )
      end

      def matches?(key_desc : String) : Bool
        parts = key_desc.downcase.split('+').map(&.strip)
        expected_ctrl = parts.includes?("ctrl")
        expected_alt = parts.includes?("alt") || parts.includes?("meta")
        expected_shift = parts.includes?("shift")
        base_name = parts.reject { |p| ["ctrl", "alt", "meta", "shift"].includes?(p) }.first? || ""

        return false unless @ctrl == expected_ctrl
        return false unless @alt == expected_alt
        return false unless @shift == expected_shift

        name_lower = @key.downcase
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

      def self.from_event(event : Terminal::KeyEvent) : KeyMsg
        new(
          key: event.name,
          char: event.char,
          ctrl: event.ctrl?,
          alt: event.alt?,
          shift: event.shift?
        )
      end
    end

    # Dispatched when a mouse event occurs.
    class MouseMsg < Msg
      getter x : Int32
      getter y : Int32
      getter button : Terminal::MouseButton
      getter action : Terminal::MouseAction

      def initialize(@x : Int32, @y : Int32, @button : Terminal::MouseButton, @action : Terminal::MouseAction)
      end

      def self.from_event(event : Terminal::MouseEvent) : MouseMsg
        new(
          x: event.x,
          y: event.y,
          button: event.button,
          action: event.action
        )
      end
    end

    # Dispatched when terminal window dimensions change.
    class WindowSizeMsg < Msg
      getter width : Int32
      getter height : Int32

      def initialize(@width : Int32, @height : Int32)
      end
    end

    # Dispatched on timer ticks.
    class TickMsg < Msg
      getter time : Time

      def initialize(@time : Time = Time.local)
      end
    end

    # Dispatched to terminate the application.
    class QuitMsg < Msg
    end

    # Generic message wrapper for custom user events.
    class CustomMsg(T) < Msg
      getter value : T

      def initialize(@value : T)
      end
    end
  end
end
