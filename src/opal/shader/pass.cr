require "./context"
require "../ui/buffer"

module Opal
  module Shader
    # Abstract base class for a single shader post-processing pass.
    abstract class Pass
      property region : Rect?
      property? enabled : Bool = true

      def initialize(@region : Rect? = nil)
      end

      abstract def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
    end

    # Fragment shader pass that executes an arbitrary procedural block over each cell.
    class FragmentPass < Pass
      getter block : Proc(ShaderContext, Nil)

      def initialize(region : Rect? = nil, &block : ShaderContext -> Nil)
        super(region)
        @block = block
      end

      def apply(source : UI::Buffer, target : UI::Buffer, time : Float64, frame : UInt64) : Nil
        return unless @enabled

        rx = @region.try(&.x) || 0
        ry = @region.try(&.y) || 0
        rw = @region.try(&.width) || source.width
        rh = @region.try(&.height) || source.height

        # Clamp bounds to source buffer
        rx = rx.clamp(0, source.width)
        ry = ry.clamp(0, source.height)
        rw = rw.clamp(0, source.width - rx)
        rh = rh.clamp(0, source.height - ry)

        return if rw <= 0 || rh <= 0

        # Preallocate a single context and reuse in-place to eliminate GC allocation spikes
        first_cell = source.get(rx, ry)
        ctx = ShaderContext.new(
          x: rx,
          y: ry,
          local_x: 0,
          local_y: 0,
          width: source.width,
          height: source.height,
          region_width: rw,
          region_height: rh,
          time: time,
          frame: frame,
          source_buffer: source,
          cell: first_cell
        )

        (ry...(ry + rh)).each do |y|
          (rx...(rx + rw)).each do |x|
            orig_cell = source.get(x, y)
            ctx.reset(
              x: x,
              y: y,
              local_x: x - rx,
              local_y: y - ry,
              width: source.width,
              height: source.height,
              region_width: rw,
              region_height: rh,
              time: time,
              frame: frame,
              source_buffer: source,
              cell: orig_cell
            )

            @block.call(ctx)

            unless ctx.discarded?
              target.set(x, y, ctx.cell)
            end
          end
        end
      end
    end
  end
end
