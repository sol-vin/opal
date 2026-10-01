require "../element"
require "../control"

module Opal
  module UI
    # Container that manages multiple child views and displays only the active one by key.
    # Inspired by Python Textual's ContentSwitcher.
    # Preserves child element states across view switches without rebuilding trees.
    class ContentSwitcher < Control
      getter views : Hash(String, Element)
      property current : String?

      def children : Array(Element)
        @views.values
      end

      def initialize(
        @views : Hash(String, Element) = {} of String => Element,
        @current : String? = nil,
      )
        super()
        @current ||= @views.keys.first?
      end

      # Adds a named child view to the switcher
      def set_view(name : String, element : Element) : self
        @views[name] = element
        @current ||= name
        self
      end

      # Switches active view by name
      def switch_to(name : String) : self
        if @views.has_key?(name)
          @current = name
        end
        self
      end

      # Returns currently active element
      def active_element : Element?
        if cur = @current
          @views[cur]?
        else
          nil
        end
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        if (el = active_element).is_a?(Control)
          el.handle_key(event)
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        if (el = active_element).is_a?(Control)
          el.handle_mouse(event)
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if el = active_element
          el.preferred_size(available_w, available_h)
        else
          {0, 0}
        end
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        if el = active_element
          el.render(buffer, x, y, width, height)
        end
      end
    end
  end
end
