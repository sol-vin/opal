require "../element"
require "../buffer"
require "../../style/color"
require "../../style/visual_width"
require "../../terminal/driver"

module Opal
  module UI
    enum ColorPickerShape
      Cube3D
      Sphere3D
      Circle2D
      Square2D

      def display_name : String
        case self
        when Cube3D   then "3D RGB Cube"
        when Sphere3D then "3D Color Sphere"
        when Circle2D then "2D Polar Wheel"
        when Square2D then "2D Spectrum Map"
        else               "Color Picker"
        end
      end
    end

    # Interactive 2D/3D Color Picker featuring rotatable 3D RGB cubes, 3D color spheres,
    # 2D polar circle color wheels, and square spectrums with virtual cursor raycasting.
    class ColorPicker3D < Element
      property shape : ColorPickerShape
      property pitch : Float64 # Rotation around X-axis (radians)
      property yaw : Float64   # Rotation around Y-axis (radians)
      property roll : Float64  # Rotation around Z-axis (radians)
      property? auto_rotate : Bool
      property cursor_x : Int32
      property cursor_y : Int32
      property selected_color : Color
      property lightness : Float64 = 0.5
      property? confirmed : Bool = false
      property size : Int32 = 12

      def initialize(
        @shape : ColorPickerShape = ColorPickerShape::Cube3D,
        @pitch : Float64 = 0.42,
        @yaw : Float64 = 0.58,
        @roll : Float64 = 0.0,
        @auto_rotate : Bool = false,
        initial_color : Color = Color.hex("#89B4FA"),
        @size : Int32 = 12,
      )
        @selected_color = initial_color
        @cursor_x = 12
        @cursor_y = 6
      end

      # Helper to convert HSL to 24-bit RGB Color
      def self.hsl_to_rgb(h : Float64, s : Float64, l : Float64) : Color
        h_norm = (h % 360.0) / 360.0
        s_clamped = s.clamp(0.0, 1.0)
        l_clamped = l.clamp(0.0, 1.0)

        if s_clamped == 0.0
          gray = (l_clamped * 255.0).round.to_u8
          return Color.rgb(gray, gray, gray)
        end

        q = l_clamped < 0.5 ? l_clamped * (1.0 + s_clamped) : l_clamped + s_clamped - l_clamped * s_clamped
        p = 2.0 * l_clamped - q

        hue_to_rgb = ->(t : Float64) : Float64 {
          t_val = t
          t_val += 1.0 if t_val < 0.0
          t_val -= 1.0 if t_val > 1.0
          if t_val < 1.0 / 6.0
            p + (q - p) * 6.0 * t_val
          elsif t_val < 1.0 / 2.0
            q
          elsif t_val < 2.0 / 3.0
            p + (q - p) * (2.0 / 3.0 - t_val) * 6.0
          else
            p
          end
        }

        r = (hue_to_rgb.call(h_norm + 1.0 / 3.0) * 255.0).round.to_u8
        g = (hue_to_rgb.call(h_norm) * 255.0).round.to_u8
        b = (hue_to_rgb.call(h_norm - 1.0 / 3.0) * 255.0).round.to_u8

        Color.rgb(r, g, b)
      end

      def cycle_shape : Nil
        @shape = case @shape
                 when ColorPickerShape::Cube3D   then ColorPickerShape::Sphere3D
                 when ColorPickerShape::Sphere3D then ColorPickerShape::Circle2D
                 when ColorPickerShape::Circle2D then ColorPickerShape::Square2D
                 when ColorPickerShape::Square2D then ColorPickerShape::Cube3D
                 else                                 ColorPickerShape::Cube3D
                 end
      end

      def tick(delta_time : Float64 = 0.05) : Nil
        if @auto_rotate
          @yaw += delta_time * 0.8
          @pitch += delta_time * 0.3
        end
      end

      def handle_key(key : Terminal::KeyEvent) : Bool
        case key.name
        # 3D Turning / Rotation keys
        when "w"
          @pitch -= 0.12
          true
        when "s"
          @pitch += 0.12
          true
        when "a"
          @yaw -= 0.12
          true
        when "d"
          @yaw += 0.12
          true
        # Virtual cursor movement
        when "up"
          @cursor_y = Math.max(0, @cursor_y - 1)
          true
        when "down"
          @cursor_y = Math.min(18, @cursor_y + 1)
          true
        when "left"
          @cursor_x = Math.max(0, @cursor_x - 1)
          true
        when "right"
          @cursor_x = Math.min(32, @cursor_x + 1)
          true
        # Mode & Controls
        when "m"
          cycle_shape
          true
        when "space"
          @auto_rotate = !@auto_rotate
          true
        when "+", "="
          @lightness = (@lightness + 0.05).clamp(0.0, 1.0)
          true
        when "-", "_"
          @lightness = (@lightness - 0.05).clamp(0.0, 1.0)
          true
        when "enter"
          @confirmed = true
          true
        else
          false
        end
      end

      def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
        {Math.min(available_w, 70), Math.min(available_h, 20)}
      end

      def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
        return if width < 30 || height < 10

        cur_y = y

        # 1. Header with Active Shape Badge
        buffer.put_string(x, cur_y, "🔮 2D/3D Color Spectrum Studio", fg: Color.cyan, bold: true)
        shape_badge = " [ #{@shape.display_name} ] "
        buffer.put_string(x + 32, cur_y, shape_badge, fg: Color.black, bg: Color.cyan, bold: true)
        cur_y += 1
        buffer.put_string(x, cur_y, "─" * Math.min(width, 68), fg: Color.bright_black)
        cur_y += 1

        canvas_w = (width * 0.52).to_i.clamp(20, 36)
        canvas_h = (height - 4).clamp(8, 16)
        canvas_x = x + 1
        canvas_y = cur_y

        # Clear canvas area
        (0...canvas_h).each do |cy|
          buffer.put_string(canvas_x, canvas_y + cy, " " * canvas_w)
        end

        # Z-Buffer for 3D depth testing
        z_buf = Array(Float64).new(canvas_w * canvas_h, -1000.0)

        # 2. Render Selected Shape
        case @shape
        when ColorPickerShape::Cube3D
          render_3d_cube(buffer, canvas_x, canvas_y, canvas_w, canvas_h, z_buf)
        when ColorPickerShape::Sphere3D
          render_3d_sphere(buffer, canvas_x, canvas_y, canvas_w, canvas_h, z_buf)
        when ColorPickerShape::Circle2D
          render_2d_circle(buffer, canvas_x, canvas_y, canvas_w, canvas_h)
        when ColorPickerShape::Square2D
          render_2d_square(buffer, canvas_x, canvas_y, canvas_w, canvas_h)
        end

        # 3. Raycast Sample Color at Virtual Cursor Position
        cur_screen_x = canvas_x + @cursor_x.clamp(0, canvas_w - 1)
        cur_screen_y = canvas_y + @cursor_y.clamp(0, canvas_h - 1)
        sampled_cell = buffer.get(cur_screen_x, cur_screen_y)

        if sampled_cell.fg.type != Color::Type::None && sampled_cell.char != ' '
          @selected_color = sampled_cell.fg
        end

        # Draw Virtual Cursor Crosshair over the surface
        cursor_char = '✛'
        buffer.put_char(cur_screen_x, cur_screen_y, cursor_char, fg: Color.bright_white, bg: Color.magenta, bold: true)

        # 4. Info Panel on Right Side
        info_x = canvas_x + canvas_w + 3
        info_w = (x + width) - info_x
        i_y = canvas_y

        # Swatch Box
        buffer.put_string(info_x, i_y, "Selected Swatch:", fg: Color.white, bold: true)
        i_y += 1

        (0...2).each do |s_row|
          (0...14).each do |s_col|
            buffer.put_char(info_x + s_col, i_y + s_row, '█', fg: @selected_color)
          end
        end
        i_y += 3

        # Color Readouts
        r_u, g_u, b_u = @selected_color.to_rgb
        buffer.put_string(info_x, i_y, "Hex:       #{@selected_color.to_hex}", fg: Color.bright_white, bold: true)
        i_y += 1
        buffer.put_string(info_x, i_y, "RGB:       (#{r_u}, #{g_u}, #{b_u})", fg: Color.cyan)
        i_y += 1

        # Calculate approximate HSV
        r_f = r_u.to_f / 255.0
        g_f = g_u.to_f / 255.0
        b_f = b_u.to_f / 255.0
        c_max = [r_f, g_f, b_f].max
        c_min = [r_f, g_f, b_f].min
        diff = c_max - c_min
        hue_deg = if diff == 0.0
                    0.0
                  elsif c_max == r_f
                    (60.0 * ((g_f - b_f) / diff) + 360.0) % 360.0
                  elsif c_max == g_f
                    (60.0 * ((b_f - r_f) / diff) + 120.0) % 360.0
                  else
                    (60.0 * ((r_f - g_f) / diff) + 240.0) % 360.0
                  end
        sat_pct = c_max == 0.0 ? 0 : ((diff / c_max) * 100.0).round.to_i
        val_pct = (c_max * 100.0).round.to_i
        buffer.put_string(info_x, i_y, "HSV:       #{hue_deg.round.to_i}°, #{sat_pct}%, #{val_pct}%", fg: Color.yellow)
        i_y += 2

        # 3D Transform Readouts
        pitch_deg = (@pitch * 180.0 / Math::PI).round.to_i % 360
        yaw_deg = (@yaw * 180.0 / Math::PI).round.to_i % 360
        buffer.put_string(info_x, i_y, "Pitch:     #{pitch_deg}°", fg: Color.bright_black)
        i_y += 1
        buffer.put_string(info_x, i_y, "Yaw:       #{yaw_deg}°", fg: Color.bright_black)
        i_y += 1
        buffer.put_string(info_x, i_y, "Cursor:    (X: #{@cursor_x}, Y: #{@cursor_y})", fg: Color.bright_black)
        i_y += 2

        # Controls Legend
        foot_y = y + height - 2
        buffer.put_string(x, foot_y, "─" * Math.min(width, 68), fg: Color.bright_black)
        foot_y += 1
        hints = " [W/A/S/D] Turn 3D   [↑/↓/←/→] Raycast Cursor   [M] Shape   [Space] Auto-Spin "
        buffer.put_string(x, Math.min(foot_y, buffer.height - 1), hints, fg: Color.bright_black)
      end

      # -----------------------------------------------------------------------
      # 3D RGB Cube Rendering with Rotation & Depth Buffering
      # -----------------------------------------------------------------------
      private def render_3d_cube(
        buffer : Buffer,
        cx : Int32,
        cy : Int32,
        cw : Int32,
        ch : Int32,
        z_buf : Array(Float64)
      ) : Nil
        center_x = cx + (cw // 2)
        center_y = cy + (ch // 2)
        scale = (ch.to_f * 0.32)

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        # 6 Faces of the Cube with Normal vectors
        faces = [
          { {0.0, 0.0, 1.0}, :z, 1.0 },   # Front
          { {0.0, 0.0, -1.0}, :z, -1.0 }, # Back
          { {0.0, -1.0, 0.0}, :y, -1.0 }, # Top
          { {0.0, 1.0, 0.0}, :y, 1.0 },   # Bottom
          { {-1.0, 0.0, 0.0}, :x, -1.0 }, # Left
          { {1.0, 0.0, 0.0}, :x, 1.0 },   # Right
        ]

        steps = 10
        faces.each do |face_normal, axis, axis_val|
          nx, ny, nz = face_normal

          # Rotate normal
          nx1 = nx * cos_y + nz * sin_y
          nz1 = -nx * sin_y + nz * cos_y
          ny2 = ny * cos_p - nz1 * sin_p
          nz2 = ny * sin_p + nz1 * cos_p

          # Back-face culling: only draw faces pointing towards viewer
          next if nz2 <= 0.0

          (0..steps).each do |si|
            u_coord = (si.to_f / steps.to_f) * 2.0 - 1.0
            (0..steps).each do |sj|
              v_coord = (sj.to_f / steps.to_f) * 2.0 - 1.0

              # Compute 3D point (x, y, z) on face
              px, py, pz = case axis
                           when :z then {u_coord, v_coord, axis_val}
                           when :y then {u_coord, axis_val, v_coord}
                           else         {axis_val, u_coord, v_coord}
                           end

              # Rotate point
              px1 = px * cos_y + pz * sin_y
              pz1 = -px * sin_y + pz * cos_y

              py2 = py * cos_p - pz1 * sin_p
              pz2 = py * sin_p + pz1 * cos_p

              # Terminal Aspect Ratio Correction (~2:1)
              sx = center_x + (px1 * scale * 2.0).round.to_i
              sy = center_y + (py2 * scale).round.to_i

              local_canvas_x = sx - cx
              local_canvas_y = sy - cy

              if local_canvas_x >= 0 && local_canvas_x < cw && local_canvas_y >= 0 && local_canvas_y < ch
                buf_idx = local_canvas_y * cw + local_canvas_x
                if pz2 > z_buf[buf_idx]
                  z_buf[buf_idx] = pz2

                  # Map point coordinate to TrueColor RGB
                  r_byte = ((px + 1.0) * 127.5).clamp(0.0, 255.0).to_u8
                  g_byte = ((py + 1.0) * 127.5).clamp(0.0, 255.0).to_u8
                  b_byte = ((pz + 1.0) * 127.5).clamp(0.0, 255.0).to_u8
                  cube_color = Color.rgb(r_byte, g_byte, b_byte)

                  buffer.put_char(sx, sy, '█', fg: cube_color)
                end
              end
            end
          end
        end
      end

      # -----------------------------------------------------------------------
      # 3D Color Sphere Rendering with Rotation & Depth Buffering
      # -----------------------------------------------------------------------
      private def render_3d_sphere(
        buffer : Buffer,
        cx : Int32,
        cy : Int32,
        cw : Int32,
        ch : Int32,
        z_buf : Array(Float64)
      ) : Nil
        center_x = cx + (cw // 2)
        center_y = cy + (ch // 2)
        radius = (ch.to_f * 0.38)

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        lat_steps = 14
        lon_steps = 24

        (0..lat_steps).each do |lat_i|
          phi = (lat_i.to_f / lat_steps.to_f) * Math::PI - (Math::PI / 2.0) # -PI/2 .. PI/2
          lightness_val = (lat_i.to_f / lat_steps.to_f)

          (0..lon_steps).each do |lon_i|
            theta = (lon_i.to_f / lon_steps.to_f) * 2.0 * Math::PI
            hue_val = (theta * 180.0 / Math::PI)

            px = Math.cos(phi) * Math.cos(theta)
            py = Math.sin(phi)
            pz = Math.cos(phi) * Math.sin(theta)

            # Rotate point
            px1 = px * cos_y + pz * sin_y
            pz1 = -px * sin_y + pz * cos_y

            py2 = py * cos_p - pz1 * sin_p
            pz2 = py * sin_p + pz1 * cos_p

            next if pz2 <= 0.0 # Back-face cull

            sx = center_x + (px1 * radius * 2.0).round.to_i
            sy = center_y + (py2 * radius).round.to_i

            local_canvas_x = sx - cx
            local_canvas_y = sy - cy

            if local_canvas_x >= 0 && local_canvas_x < cw && local_canvas_y >= 0 && local_canvas_y < ch
              buf_idx = local_canvas_y * cw + local_canvas_x
              if pz2 > z_buf[buf_idx]
                z_buf[buf_idx] = pz2
                sphere_c = ColorPicker3D.hsl_to_rgb(hue_val, 1.0, lightness_val)
                buffer.put_char(sx, sy, '█', fg: sphere_c)
              end
            end
          end
        end
      end

      # -----------------------------------------------------------------------
      # 2D Polar Circle Color Wheel
      # -----------------------------------------------------------------------
      private def render_2d_circle(buffer : Buffer, cx : Int32, cy : Int32, cw : Int32, ch : Int32) : Nil
        center_x = cx + (cw // 2)
        center_y = cy + (ch // 2)
        radius = (ch.to_f * 0.44)

        (-ch // 2..ch // 2).each do |dy|
          sy = center_y + dy
          next if sy < cy || sy >= cy + ch

          adj_dy = dy.to_f * 2.0 # Aspect ratio compensation

          (-cw // 2..cw // 2).each do |dx|
            sx = center_x + dx
            next if sx < cx || sx >= cx + cw

            dist = Math.sqrt(dx.to_f * dx.to_f + adj_dy * adj_dy) / (radius * 2.0)
            if dist <= 1.0
              angle = (Math.atan2(adj_dy, dx.to_f) * 180.0 / Math::PI + 360.0) % 360.0
              wheel_c = ColorPicker3D.hsl_to_rgb(angle, dist, @lightness)
              buffer.put_char(sx, sy, '█', fg: wheel_c)
            end
          end
        end
      end

      # -----------------------------------------------------------------------
      # 2D Cartesian Square Spectrum Map
      # -----------------------------------------------------------------------
      private def render_2d_square(buffer : Buffer, cx : Int32, cy : Int32, cw : Int32, ch : Int32) : Nil
        grid_w = Math.min(cw - 2, 28)
        grid_h = Math.min(ch - 2, 12)
        start_x = cx + ((cw - grid_w) // 2)
        start_y = cy + ((ch - grid_h) // 2)

        (0...grid_h).each do |gy|
          v_ratio = 1.0 - (gy.to_f / grid_h.to_f) # Saturation / Value
          (0...grid_w).each do |gx|
            hue_deg = (gx.to_f / grid_w.to_f) * 360.0
            square_c = ColorPicker3D.hsl_to_rgb(hue_deg, v_ratio, @lightness)
            buffer.put_char(start_x + gx, start_y + gy, '█', fg: square_c)
          end
        end
      end
    end
  end

  # High-level standalone runner for 3D rotatable color picker
  def self.pick_color_3d(
    initial_shape : UI::ColorPickerShape = UI::ColorPickerShape::Cube3D,
    auto_rotate : Bool = false,
    driver : Terminal::Driver? = nil,
  ) : Color?
    drv = driver || Terminal.default_driver
    picker = UI::ColorPicker3D.new(shape: initial_shape, auto_rotate: auto_rotate)

    render_frame = -> {
      w, h = drv.size
      buf = UI::Buffer.new(w, h)
      picker.render(buf, 0, 0, w, h)
      drv.write(Terminal::Screen::CLEAR_ALL)
      drv.write(Terminal::Screen.move_to(1, 1))
      drv.write(buf.to_s)
      drv.flush
    }

    result : Color? = nil

    drv.raw_mode do
      drv.hide_cursor
      render_frame.call

      loop do
        event = drv.read_event
        next unless event
        should_redraw = false

        case event
        when Terminal::KeyEvent
          if event.matches?("escape") || event.matches?("ctrl+c")
            break
          end

          if picker.handle_key(event)
            should_redraw = true
            if picker.confirmed?
              result = picker.selected_color
              break
            end
          end
        end

        render_frame.call if should_redraw
      end
    ensure
      drv.show_cursor
    end

    result
  end
end
