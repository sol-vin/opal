require "../element"
require "../rect"

module Opal
  module UI
    # A container element that clips all child rendering strictly within its bounds
    # using hardware-inspired scissor testing.
    class ScissorContainer < Element
      property rect : Rect
      property child : Element?

      def initialize(@rect : Rect, @child : Element? = nil)
      end

      def initialize(x : Int32, y : Int32, width : Int32, height : Int32, @child : Element? = nil)
        @rect = Rect.new(x, y, width, height)
      end

      def children : Array(Element)
        if ch = @child
          [ch]
        else
          [] of Element
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = @rect.width > 0 ? @rect.width : available_w
        h = @rect.height > 0 ? @rect.height : available_h
        {w, h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        clip_target = if @rect.x == 0 && @rect.y == 0
                        Rect.new(x, y, Math.min(width, @rect.width > 0 ? @rect.width : width), Math.min(height, @rect.height > 0 ? @rect.height : height))
                      else
                        @rect
                      end

        buffer.with_scissor(clip_target) do
          if ch = @child
            ch.render(buffer, clip_target.x, clip_target.y, clip_target.width, clip_target.height)
          end
        end
      end
    end
  end
end
