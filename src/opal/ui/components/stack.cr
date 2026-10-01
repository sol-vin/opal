require "../element"

module Opal
  module UI
    # Vertical layout container stacking children from top to bottom.
    class VStack < Element
      getter children : Array(Element)
      property spacing : Int32

      def initialize(@spacing : Int32 = 0)
        @children = [] of Element
      end

      def initialize(elements : Enumerable(Element), @spacing : Int32 = 0)
        @children = [] of Element
        elements.each { |e| @children << e }
      end

      def self.new(spacing : Int32 = 0, &)
        sb = StackBuilder.new
        with sb yield sb
        new(sb.elements, spacing: spacing)
      end

      def add(element : Element) : self
        @children << element
        self
      end

      def <<(element : Element) : self
        add(element)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_h = 0
        max_w = 0

        @children.each_with_index do |child, idx|
          w, h = child.preferred_size(available_w, Math.max(0, available_h - total_h))
          max_w = Math.max(max_w, w)
          total_h += h
          total_h += @spacing if idx < @children.size - 1
        end

        {Math.min(max_w, available_w), Math.min(total_h, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        cur_y = y

        @children.each_with_index do |child, idx|
          avail_h = Math.max(0, (y + height) - cur_y)
          break if avail_h <= 0

          _, child_h = child.preferred_size(width, avail_h)
          render_h = Math.min(child_h, avail_h)
          if render_h > 0
            buffer.with_clip(x, cur_y, width, render_h) do
              child.render(buffer, x, cur_y, width, render_h)
            end
          end
          cur_y += render_h
          cur_y += @spacing if idx < @children.size - 1
        end
      end
    end

    # Horizontal layout container placing children side-by-side from left to right.
    class HStack < Element
      getter children : Array(Element)
      property spacing : Int32

      def initialize(@spacing : Int32 = 0)
        @children = [] of Element
      end

      def initialize(elements : Enumerable(Element), @spacing : Int32 = 0)
        @children = [] of Element
        elements.each { |e| @children << e }
      end

      def self.new(spacing : Int32 = 0, &)
        sb = StackBuilder.new
        with sb yield sb
        new(sb.elements, spacing: spacing)
      end

      def add(element : Element) : self
        @children << element
        self
      end

      def <<(element : Element) : self
        add(element)
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        total_w = 0
        max_h = 0

        @children.each_with_index do |child, idx|
          w, h = child.preferred_size(Math.max(0, available_w - total_w), available_h)
          total_w += w
          total_w += @spacing if idx < @children.size - 1
          max_h = Math.max(max_h, h)
        end

        {Math.min(total_w, available_w), Math.min(max_h, available_h)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        cur_x = x

        @children.each_with_index do |child, idx|
          avail_w = Math.max(0, (x + width) - cur_x)
          break if avail_w <= 0

          child_w, _ = child.preferred_size(avail_w, height)
          render_w = Math.min(child_w, avail_w)
          if render_w > 0
            buffer.with_clip(cur_x, y, render_w, height) do
              child.render(buffer, cur_x, y, render_w, height)
            end
          end
          cur_x += render_w
          cur_x += @spacing if idx < @children.size - 1
        end
      end
    end
  end
end
