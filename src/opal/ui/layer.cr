require "./buffer"
require "./rect"
require "./element"

module Opal
  module UI
    # Represents an isolated 2D drawing surface with position, z-index, visibility,
    # and clipping rectangle. Layers allow complex UIs, floating windows, dropdowns,
    # and overlays to be rendered independently and composited in depth order.
    class Layer
      property x : Int32
      property y : Int32
      property z_index : Int32
      property? visible : Bool = true
      property? transparent_bg : Bool = true
      property opacity : Float64 = 1.0
      property clip_rect : Rect? = nil
      getter buffer : Buffer

      def initialize(
        width : Int32,
        height : Int32,
        @x : Int32 = 0,
        @y : Int32 = 0,
        @z_index : Int32 = 0,
        @visible : Bool = true,
        @transparent_bg : Bool = true,
        @clip_rect : Rect? = nil,
      )
        @buffer = Buffer.new(Math.max(1, width), Math.max(1, height))
      end

      def width : Int32
        @buffer.width
      end

      def height : Int32
        @buffer.height
      end

      # Clears the layer's internal buffer.
      def clear : Nil
        @buffer.clear
      end

      # Resizes the layer's internal buffer, preserving existing content if possible.
      def resize(new_width : Int32, new_height : Int32) : self
        w = Math.max(1, new_width)
        h = Math.max(1, new_height)
        return self if w == width && h == height

        new_buf = Buffer.new(w, h)
        new_buf.blit(@buffer, 0, 0, ignore_spaces: false)
        @buffer = new_buf
        self
      end

      # Renders a declarative UI element onto this layer.
      def render_element(
        element : Element,
        rel_x : Int32 = 0,
        rel_y : Int32 = 0,
        render_w : Int32? = nil,
        render_h : Int32? = nil,
      ) : Nil
        target_w = render_w || (width - rel_x)
        target_h = render_h || (height - rel_y)
        element.render(@buffer, rel_x, rel_y, Math.max(0, target_w), Math.max(0, target_h))
      end

      # Blits this layer onto a target buffer at (@x, @y), respecting visibility,
      # transparent_bg, and any layer clipping rectangle.
      def blit_to(target : Buffer) : Nil
        return unless @visible

        if cr = @clip_rect
          target.with_clip(cr.x, cr.y, cr.width, cr.height) do
            target.blit(@buffer, @x, @y, ignore_spaces: @transparent_bg)
          end
        else
          target.blit(@buffer, @x, @y, ignore_spaces: @transparent_bg)
        end
      end
    end
  end
end
