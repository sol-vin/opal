require "./layer"

module Opal
  module UI
    # Manages a depth-ordered stack of `Layer` surfaces.
    # Composites layers in sorted z-index order onto a target buffer,
    # ensuring overlays, floating windows, dropdowns, and notifications
    # render with correct depth, transparency, and clipping.
    class LayerStack
      # Standard semantic z-index tier constants
      TIER_BACKGROUND =    0
      TIER_CONTENT    =  100
      TIER_WINDOWS    =  200
      TIER_OVERLAYS   =  500
      TIER_MODALS     =  800
      TIER_TOASTS     =  900
      TIER_CURSOR     = 1000

      getter layers : Array(Layer)

      def initialize
        @layers = [] of Layer
      end

      # Adds an existing layer to the stack.
      def add(layer : Layer) : Layer
        @layers << layer unless @layers.includes?(layer)
        layer
      end

      # Factory method to create, configure, and register a new layer.
      def create_layer(
        width : Int32,
        height : Int32,
        z_index : Int32 = TIER_CONTENT,
        x : Int32 = 0,
        y : Int32 = 0,
        transparent_bg : Bool = true,
      ) : Layer
        layer = Layer.new(
          width: width,
          height: height,
          x: x,
          y: y,
          z_index: z_index,
          transparent_bg: transparent_bg
        )
        add(layer)
      end

      # Removes a layer from the stack.
      def remove(layer : Layer) : Bool
        @layers.delete(layer) ? true : false
      end

      # Elevates a layer above all other layers currently in its tier.
      def bring_to_front(layer : Layer) : self
        return self unless @layers.includes?(layer)
        max_z = @layers.map(&.z_index).max? || 0
        layer.z_index = max_z + 1
        self
      end

      # Lowers a layer below all other layers in the stack.
      def send_to_back(layer : Layer) : self
        return self unless @layers.includes?(layer)
        min_z = @layers.map(&.z_index).min? || 0
        layer.z_index = min_z - 1
        self
      end

      # Clears all registered layers from the stack.
      def clear : self
        @layers.clear
        self
      end

      # Composites all visible layers onto the target buffer in ascending z-index order.
      def compose(target : Buffer) : Nil
        # Sort stable by z_index
        sorted_layers = @layers.select(&.visible?).sort_by(&.z_index)
        sorted_layers.each do |layer|
          layer.blit_to(target)
        end
      end
    end
  end
end
