require "../element"
require "../../graphics/primitives_2d"

module Opal
  module UI
    # Declarative 2D canvas element allowing custom vector line, shape,
    # and primitive drawing operations via a drawing callback.
    class Canvas2D < Element
      getter draw_callback : Proc(Buffer, Int32, Int32, Int32, Int32, Nil)
      property width : Int32?
      property height : Int32?

      def initialize(
        @width : Int32? = nil,
        @height : Int32? = nil,
        &block : (Buffer, Int32, Int32, Int32, Int32) -> Nil
      )
        @draw_callback = block
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = @width || available_w
        h = @height || available_h
        {w, h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        buffer.with_clip(x, y, width, height) do
          @draw_callback.call(buffer, x, y, width, height)
        end
      end
    end
  end
end
