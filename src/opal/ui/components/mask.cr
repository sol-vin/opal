require "../element"
require "../mask"

module Opal
  module UI
    # A container element that renders its child elements under an active MaskMap
    # with optional feathered alpha dithering.
    class MaskContainer < Element
      property mask : MaskMap
      property child : Element?
      property? feather : Bool = true
      property offset_x : Int32 = 0
      property offset_y : Int32 = 0

      def initialize(
        @mask : MaskMap,
        @child : Element? = nil,
        @feather : Bool = true,
        @offset_x : Int32 = 0,
        @offset_y : Int32 = 0,
      )
      end

      def children : Array(Element)
        if ch = @child
          [ch]
        else
          [] of Element
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        w = @mask.width > 0 ? @mask.width : available_w
        h = @mask.height > 0 ? @mask.height : available_h
        {w, h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        eff_ox = @offset_x == 0 ? x : @offset_x
        eff_oy = @offset_y == 0 ? y : @offset_y

        buffer.with_mask(@mask, offset_x: eff_ox, offset_y: eff_oy, feather: @feather) do
          if ch = @child
            ch.render(buffer, x, y, width, height)
          end
        end
      end
    end
  end
end
