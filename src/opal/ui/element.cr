require "./buffer"
require "./themable"
require "../terminal/info"

module Opal
  module UI
    # Base class for all visual components in the declarative UI hierarchy.
    abstract class Element
      include Themable

      property id : String? = nil
      property classes : Set(String) = Set(String).new

      abstract def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
      abstract def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}

      # Returns child elements for hierarchical tree traversal and DOM querying
      def children : Array(Element)
        [] of Element
      end

      def add_class(name : String) : self
        @classes << name
        self
      end

      def remove_class(name : String) : self
        @classes.delete(name)
        self
      end

      def has_class?(name : String) : Bool
        @classes.includes?(name)
      end

      # Queries all descendants matching a CSS-like selector string
      def query(selector : String) : Array(Element)
        QueryEngine.query(self, selector)
      end

      # Queries all descendants matching a specific Crystal type class
      def query(klass : T.class) : Array(T) forall T
        QueryEngine.query_type(self, klass)
      end

      # Queries the first descendant matching selector, or nil
      def query_one?(selector : String) : Element?
        query(selector).first?
      end

      # Queries the first descendant matching selector, or raises KeyError
      def query_one(selector : String) : Element
        query_one?(selector) || raise KeyError.new("No element matched selector '#{selector}'")
      end

      # Queries the first descendant matching type class, or nil
      def query_one?(klass : T.class) : T? forall T
        query(klass).first?
      end

      # Queries the first descendant matching type class, or raises KeyError
      def query_one(klass : T.class) : T forall T
        query_one?(klass) || raise KeyError.new("No element matched type #{klass}")
      end

      # Returns the preferred size for one-shot print mode rendering,
      # where height should expand to fit all content rather than clamping to viewport rows.
      def preferred_print_size(available_w : Int32) : {Int32, Int32}
        preferred_size(available_w, Int32::MAX)
      end

      # Print-mode rendering hook that components can override if their print layout differs from interactive layout
      def render_print(buffer : Buffer, width : Int32, height : Int32) : Nil
        render(buffer, 0, 0, width, height)
      end

      # Renders the element into a string buffer in one-shot print mode.
      # If color is nil, auto-detects from TTY and NO_COLOR environment variable.
      def to_print_s(width : Int32? = nil, color : Bool? = nil, theme : Theme? = nil) : String
        term_width = (Terminal::Info.new.width rescue 80)
        w = width || term_width
        w = Math.max(1, w)
        pref_w, pref_h = preferred_print_size(w)
        h = Math.max(1, pref_h)
        actual_w = Math.max(1, Math.min(w, pref_w))
        actual_w = w if pref_w >= w

        buffer = Buffer.new(actual_w, h)
        th = theme || Theme.current
        prev_th = Theme.current
        Theme.current = th if theme
        begin
          render_print(buffer, actual_w, h)
        ensure
          Theme.current = prev_th if theme
        end

        use_color = if color.nil?
                      (STDOUT.tty? rescue false) && !ENV.has_key?("NO_COLOR")
                    else
                      color
                    end

        buffer.render_to_string(with_ansi: use_color)
      end

      # Alias for to_print_s
      def to_string(width : Int32? = nil, color : Bool? = nil, theme : Theme? = nil) : String
        to_print_s(width: width, color: color, theme: theme)
      end

      # Prints the element directly to an IO stream in one-shot print mode.
      def print(io : IO = STDOUT, width : Int32? = nil, color : Bool? = nil, theme : Theme? = nil) : Nil
        io.print to_print_s(width: width, color: color, theme: theme)
      end
    end
  end
end

require "./input_hookable"
require "./control"
require "./engine"
require "./query"
