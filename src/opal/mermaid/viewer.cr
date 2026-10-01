require "./ast"
require "./parser"
require "./renderer"
require "../ui/element"
require "../ui/buffer"
require "../style/border"

module Opal
  module UI
    class MermaidViewer < Element
      property source : String
      property diagram : Mermaid::Diagram
      property? scrollable : Bool = true
      property? auto_scroll : Bool = false
      property scroll_speed : Float64 = 1.0
      property scroll_y : Int32 = 0
      property scroll_x : Int32 = 0
      property border : Border = Border.rounded

      @cached_buffer : Buffer? = nil
      @internal_w : Int32 = 120
      @internal_h : Int32 = 60

      def initialize(
        @source : String,
        @scrollable : Bool = true,
        @auto_scroll : Bool = false,
        @scroll_speed : Float64 = 1.0,
        @border : Border = Border.rounded,
      )
        @diagram = Mermaid::Parser.parse(@source)
      end

      def source=(new_source : String)
        @source = new_source
        @diagram = Mermaid::Parser.parse(new_source)
        @cached_buffer = nil
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def tick(dt : Float64 = 0.0166) : Nil
        if @auto_scroll
          @scroll_y += (@scroll_speed * dt * 2.0).round.to_i
          if @scroll_y > (@internal_h - 10)
            @scroll_y = 0
          end
        end
      end

      def scroll_down(lines : Int32 = 1) : Nil
        return unless @scrollable
        @scroll_y = Math.min(@scroll_y + lines, @internal_h - 5)
      end

      def scroll_up(lines : Int32 = 1) : Nil
        return unless @scrollable
        @scroll_y = Math.max(0, @scroll_y - lines)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        # Render diagram into cached internal buffer if not already done
        buf = @cached_buffer ||= begin
          cbuf = Buffer.new(@internal_w, @internal_h)
          Mermaid::Renderer.render(@diagram, cbuf, 2, 2, @internal_w - 4, @internal_h - 4)
          cbuf
        end

        # Blit visible slice onto target buffer
        sub = buf.copy(@scroll_x, @scroll_y, width, height)
        buffer.paste(sub, x, y, BlitMode::Replace)
      end
    end

    # Async Mermaid Viewer that displays an animated throbber until the diagram string is ready
    class AsyncMermaidViewer < Element
      property viewer : MermaidViewer? = nil
      property? resolved : Bool = false
      property label : String
      property spinner_frame : Int32 = 0

      def initialize(@label : String = "Generating diagram...", &block : -> String)
        spawn do
          result = block.call
          @viewer = MermaidViewer.new(result)
          @resolved = true
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        if v = @viewer
          v.preferred_size(available_w, available_h)
        else
          {available_w, available_h}
        end
      end

      def tick : Nil
        @spinner_frame += 1
        @viewer.try(&.tick)
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        if @resolved && (v = @viewer)
          v.render(buffer, x, y, width, height)
        else
          # Render loading throbber
          spin_char = Glyphs.spinner_frame(:arc, @spinner_frame)
          status = "#{spin_char} #{@label}"
          buffer.put_string(x + (width // 2) - (status.size // 2), y + (height // 2), status, fg: Color.hex("#00f2fe"), bold: true)
        end
      end
    end
  end
end
