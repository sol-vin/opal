require "../terminal/ansi_parser"

module Opal
  module Input
    # Declarative mouse event routing, click handling, and hit-testing DSL.
    class MouseMap
      alias MouseActionCallback = Terminal::MouseEvent -> Nil

      struct ZoneHandler
        getter x_range : Range(Int32, Int32)
        getter y_range : Range(Int32, Int32)
        getter action : MouseActionCallback

        def initialize(@x_range : Range(Int32, Int32), @y_range : Range(Int32, Int32), &@action : MouseActionCallback)
        end

        def matches?(ev : Terminal::MouseEvent) : Bool
          @x_range.includes?(ev.x) && @y_range.includes?(ev.y)
        end
      end

      @click_handlers = [] of {Terminal::MouseButton?, MouseActionCallback}
      @scroll_up_handlers = [] of MouseActionCallback
      @scroll_down_handlers = [] of MouseActionCallback
      @motion_handlers = [] of MouseActionCallback
      @release_handlers = [] of MouseActionCallback
      @zones = [] of ZoneHandler

      # Registers a click handler with optional button constraint (:left, :middle, :right)
      def on(action : Symbol, button : Terminal::MouseButton? = nil, &block : Terminal::MouseEvent -> Nil) : self
        case action
        when :click
          @click_handlers << {button, block}
        when :scroll_up
          @scroll_up_handlers << block
        when :scroll_down
          @scroll_down_handlers << block
        when :motion, :drag
          @motion_handlers << block
        when :release
          @release_handlers << block
        end
        self
      end

      def on_click(button : Terminal::MouseButton? = nil, &block : Terminal::MouseEvent -> Nil) : self
        on(:click, button, &block)
      end

      def on_scroll_up(&block : Terminal::MouseEvent -> Nil) : self
        on(:scroll_up, &block)
      end

      def on_scroll_down(&block : Terminal::MouseEvent -> Nil) : self
        on(:scroll_down, &block)
      end

      # Registers a bounding-box hit test zone (e.g. for buttons, tabs, or cards)
      def zone(x : Range(Int32, Int32), y : Range(Int32, Int32), &block : Terminal::MouseEvent -> Nil) : self
        @zones << ZoneHandler.new(x, y, &block)
        self
      end

      # Dispatches a MouseEvent to all matching handlers.
      # Returns true if at least one handler processed the event, false otherwise.
      def handle(event : Terminal::MouseEvent) : Bool
        handled = false

        # Check hit-testing zones first
        if event.action == Terminal::MouseAction::Press
          @zones.each do |z|
            if z.matches?(event)
              z.action.call(event)
              handled = true
            end
          end
        end

        case event.action
        when Terminal::MouseAction::Press
          if event.button == Terminal::MouseButton::WheelUp
            @scroll_up_handlers.each(&.call(event))
            handled = true unless @scroll_up_handlers.empty?
          elsif event.button == Terminal::MouseButton::WheelDown
            @scroll_down_handlers.each(&.call(event))
            handled = true unless @scroll_down_handlers.empty?
          else
            @click_handlers.each do |btn, cb|
              if btn.nil? || btn == event.button
                cb.call(event)
                handled = true
              end
            end
          end
        when Terminal::MouseAction::Motion
          @motion_handlers.each(&.call(event))
          handled = true unless @motion_handlers.empty?
        when Terminal::MouseAction::Release
          @release_handlers.each(&.call(event))
          handled = true unless @release_handlers.empty?
        end

        handled
      end
    end
  end

  # Convenience DSL builder for mouse routing
  def self.on_mouse(&block : Input::MouseMap -> Nil) : Input::MouseMap
    mm = Input::MouseMap.new
    block.call(mm)
    mm
  end
end
