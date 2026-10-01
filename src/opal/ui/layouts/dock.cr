require "../element"
require "../control"
require "../buffer"

module Opal
  module UI
    enum DockEdge
      Top
      Bottom
      Left
      Right
      Center
    end

    struct DockItem
      getter element : Element
      getter edge : DockEdge
      getter size : Int32?

      def initialize(@element : Element, @edge : DockEdge, @size : Int32? = nil)
      end
    end

    # Modern declarative Dock layout container inspired by Python Textual's Docking system.
    # Arranges child elements docked to Top, Bottom, Left, Right, and Center,
    # computing bounds and remaining canvas automatically.
    class DockContainer < Control
      getter items : Array(DockItem)

      def children : Array(Element)
        @items.map(&.element)
      end

      def initialize(@items : Array(DockItem) = [] of DockItem)
        super()
      end

      def dock(element : Element, edge : DockEdge | Symbol, size : Int32? = nil) : self
        dock_edge = case edge
                    when DockEdge then edge
                    when :top then DockEdge::Top
                    when :bottom then DockEdge::Bottom
                    when :left then DockEdge::Left
                    when :right then DockEdge::Right
                    when :center then DockEdge::Center
                    else
                      raise ArgumentError.new("Invalid dock edge: #{edge}. Expected :top, :bottom, :left, :right, or :center")
                    end
        @items << DockItem.new(element, dock_edge, size)
        self
      end

      def dock_top(element : Element, height : Int32? = nil) : self
        @items << DockItem.new(element, DockEdge::Top, height)
        self
      end

      def dock_bottom(element : Element, height : Int32? = nil) : self
        @items << DockItem.new(element, DockEdge::Bottom, height)
        self
      end

      def dock_left(element : Element, width : Int32? = nil) : self
        @items << DockItem.new(element, DockEdge::Left, width)
        self
      end

      def dock_right(element : Element, width : Int32? = nil) : self
        @items << DockItem.new(element, DockEdge::Right, width)
        self
      end

      def dock_center(element : Element) : self
        @items << DockItem.new(element, DockEdge::Center, nil)
        self
      end

      # Computes geometry rectangles for each child given total width and height
      def compute_layout(x : Int32, y : Int32, width : Int32, height : Int32) : Array({DockItem, Int32, Int32, Int32, Int32})
        cur_x = x
        cur_y = y
        cur_w = width
        cur_h = height

        result = [] of {DockItem, Int32, Int32, Int32, Int32}

        # 1. Dock Top items
        @items.select { |it| it.edge.top? }.each do |it|
          pref_w, pref_h = it.element.preferred_size(cur_w, cur_h)
          item_h = it.size || pref_h
          item_h = item_h.clamp(0, cur_h)
          result << {it, cur_x, cur_y, cur_w, item_h}
          cur_y += item_h
          cur_h = Math.max(0, cur_h - item_h)
        end

        # 2. Dock Bottom items
        @items.select { |it| it.edge.bottom? }.each do |it|
          pref_w, pref_h = it.element.preferred_size(cur_w, cur_h)
          item_h = it.size || pref_h
          item_h = item_h.clamp(0, cur_h)
          bot_y = cur_y + cur_h - item_h
          result << {it, cur_x, bot_y, cur_w, item_h}
          cur_h = Math.max(0, cur_h - item_h)
        end

        # 3. Dock Left items
        @items.select { |it| it.edge.left? }.each do |it|
          pref_w, pref_h = it.element.preferred_size(cur_w, cur_h)
          item_w = it.size || pref_w
          item_w = item_w.clamp(0, cur_w)
          result << {it, cur_x, cur_y, item_w, cur_h}
          cur_x += item_w
          cur_w = Math.max(0, cur_w - item_w)
        end

        # 4. Dock Right items
        @items.select { |it| it.edge.right? }.each do |it|
          pref_w, pref_h = it.element.preferred_size(cur_w, cur_h)
          item_w = it.size || pref_w
          item_w = item_w.clamp(0, cur_w)
          right_x = cur_x + cur_w - item_w
          result << {it, right_x, cur_y, item_w, cur_h}
          cur_w = Math.max(0, cur_w - item_w)
        end

        # 5. Dock Center items (fill remaining canvas)
        @items.select { |it| it.edge.center? }.each do |it|
          result << {it, cur_x, cur_y, cur_w, cur_h}
        end

        result
      end

      def handle_key(event : Terminal::KeyEvent) : Bool
        @items.each do |it|
          if (el = it.element).is_a?(Control) && el.focused?
            return true if el.handle_key(event)
          end
        end
        # Fallback to any child control
        @items.each do |it|
          if (el = it.element).is_a?(Control)
            return true if el.handle_key(event)
          end
        end
        false
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        # Find which child contains mouse event
        @items.each do |it|
          if (el = it.element).is_a?(Control)
            return true if el.handle_mouse(event)
          end
        end
        false
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0

        layout = compute_layout(x, y, width, height)
        layout.each do |item, ix, iy, iw, ih|
          next if iw <= 0 || ih <= 0
          buffer.with_clip(ix, iy, iw, ih) do
            item.element.render(buffer, ix, iy, iw, ih)
          end
        end
      end
    end
  end
end
