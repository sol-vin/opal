require "../control"
require "../../graphics/primitives_3d"

module Opal
  module UI
    # Interactive 3D Mesh Control that renders rotatable, light-shaded 3D primitives
    # (Cube, Sphere, Cylinder, Pyramid, Torus) in terminal character cells.
    # Supports mouse drag rotation, wheel zooming, and keyboard controls.
    class Mesh3D < Control
      property shape : Symbol
      property pitch : Float64
      property yaw : Float64
      property roll : Float64
      property scale : Float64
      property? auto_rotate : Bool
      property? wireframe : Bool
      property color : Color

      # Drag tracking state
      @dragging : Bool = false
      @last_mouse_x : Int32 = 0
      @last_mouse_y : Int32 = 0

      def initialize(
        @shape : Symbol = :cube,
        @pitch : Float64 = 0.4,
        @yaw : Float64 = 0.6,
        @roll : Float64 = 0.0,
        @scale : Float64 = 7.0,
        @auto_rotate : Bool = false,
        @wireframe : Bool = false,
        color : Color | Symbol | String = :cyan,
      )
        super()
        @color = Color.from(color)
      end

      # Updates procedural rotation if auto_rotate is active
      def tick : Nil
        if @auto_rotate
          @yaw += 0.04
          @pitch += 0.02
        end
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        when "space", " "
          @wireframe = !@wireframe
          true
        when "r"
          @auto_rotate = !@auto_rotate
          true
        when "1"
          @shape = :cube
          true
        when "2"
          @shape = :sphere
          true
        when "3"
          @shape = :cylinder
          true
        when "4"
          @shape = :pyramid
          true
        when "5"
          @shape = :torus
          true
        when "up"
          @pitch -= 0.1
          true
        when "down"
          @pitch += 0.1
          true
        when "left"
          @yaw -= 0.1
          true
        when "right"
          @yaw += 0.1
          true
        when "+", "="
          @scale = (@scale + 1.0).clamp(2.0, 30.0)
          true
        when "-", "_"
          @scale = (@scale - 1.0).clamp(2.0, 30.0)
          true
        else
          false
        end
      end

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        case event.button
        when Terminal::MouseButton::WheelUp
          @scale = (@scale + 1.0).clamp(2.0, 30.0)
          true
        when Terminal::MouseButton::WheelDown
          @scale = (@scale - 1.0).clamp(2.0, 30.0)
          true
        when Terminal::MouseButton::Left
          case event.action
          when Terminal::MouseAction::Press
            @dragging = true
            @last_mouse_x = event.x
            @last_mouse_y = event.y
            true
          when Terminal::MouseAction::Release
            @dragging = false
            true
          when Terminal::MouseAction::Motion
            if @dragging
              dx = event.x - @last_mouse_x
              dy = event.y - @last_mouse_y
              @yaw += dx * 0.05
              @pitch += dy * 0.05
              @last_mouse_x = event.x
              @last_mouse_y = event.y
              true
            else
              false
            end
          else
            false
          end
        else
          false
        end
      end

      # Returns the Mesh3DData instance for current shape
      def current_mesh : Graphics::Mesh3DData
        case @shape
        when :sphere   then Graphics::Mesh3DData.sphere
        when :cylinder then Graphics::Mesh3DData.cylinder
        when :pyramid  then Graphics::Mesh3DData.pyramid
        when :torus    then Graphics::Mesh3DData.torus
        else                Graphics::Mesh3DData.cube
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {available_w, available_h}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width <= 0 || height <= 0
        cx = x + width // 2
        cy = y + height // 2

        buffer.with_clip(x, y, width, height) do
          Graphics::Primitives3D.render_mesh(
            buffer,
            current_mesh,
            center_x: cx,
            center_y: cy,
            scale: @scale,
            pitch: @pitch,
            yaw: @yaw,
            roll: @roll,
            wireframe: @wireframe,
            primary_color: @color
          )
        end
      end
    end
  end
end
