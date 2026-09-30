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
        when "space", " "
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

      property last_canvas_x : Int32 = 1
      property last_canvas_y : Int32 = 2
      property last_canvas_w : Int32 = 28
      property last_canvas_h : Int32 = 12

      @last_drag_x : Int32? = nil
      @last_drag_y : Int32? = nil

      def handle_mouse(event : Terminal::MouseEvent) : Bool
        cw = @last_canvas_w
        ch = @last_canvas_h
        cx = @last_canvas_x
        cy = @last_canvas_y

        case event.button
        when Terminal::MouseButton::WheelUp
          @lightness = (@lightness + 0.05).clamp(0.0, 1.0)
          true
        when Terminal::MouseButton::WheelDown
          @lightness = (@lightness - 0.05).clamp(0.0, 1.0)
          true
        when Terminal::MouseButton::Right
          # Right-click drag: Rotate 3D object
          if event.action == Terminal::MouseAction::Press
            @last_drag_x = event.x
            @last_drag_y = event.y
            true
          elsif event.action == Terminal::MouseAction::Motion
            if (last_x = @last_drag_x) && (last_y = @last_drag_y)
              dx = event.x - last_x
              dy = event.y - last_y
              @yaw += dx * 0.08
              @pitch += dy * 0.08
              @last_drag_x = event.x
              @last_drag_y = event.y
              true
            else
              @last_drag_x = event.x
              @last_drag_y = event.y
              false
            end
          elsif event.action == Terminal::MouseAction::Release
            @last_drag_x = nil
            @last_drag_y = nil
            true
          else
            false
          end
        when Terminal::MouseButton::Left
          if event.action == Terminal::MouseAction::Release
            return true
          end

          # Left-click: Choose color from surface using raycast
          # Determine canvas-local coordinates (handles 1-indexed terminal coords or 0-indexed coords)
          local_x = if event.x >= cx + 1 && event.x <= cx + cw
                      event.x - 1 - cx
                    elsif event.x >= cx && event.x < cx + cw
                      event.x - cx
                    else
                      (event.x - 1 - cx).clamp(0, cw - 1)
                    end

          local_y = if event.y >= cy + 1 && event.y <= cy + ch
                      event.y - 1 - cy
                    elsif event.y >= cy && event.y < cy + ch
                      event.y - cy
                    else
                      (event.y - 1 - cy).clamp(0, ch - 1)
                    end

          local_x = local_x.clamp(0, cw - 1)
          local_y = local_y.clamp(0, ch - 1)

          @cursor_x = local_x
          @cursor_y = local_y

          if hit_color = sample_raycast_color(local_x, local_y, cw, ch)
            @selected_color = hit_color
          end
          true
        when Terminal::MouseButton::None
          if event.action == Terminal::MouseAction::Motion && (last_x = @last_drag_x) && (last_y = @last_drag_y)
            dx = event.x - last_x
            dy = event.y - last_y
            @yaw += dx * 0.08
            @pitch += dy * 0.08
            @last_drag_x = event.x
            @last_drag_y = event.y
            true
          elsif event.action == Terminal::MouseAction::Release
            @last_drag_x = nil
            @last_drag_y = nil
            true
          else
            false
          end
        else
          if event.action == Terminal::MouseAction::Release
            @last_drag_x = nil
            @last_drag_y = nil
          end
          false
        end
      end

      # Performs mathematical raycasting at canvas-local coordinates (lx, ly)
      # and returns the surface Color if a hit occurs, or nil otherwise.
      def sample_raycast_color(lx : Int32, ly : Int32, cw : Int32? = nil, ch : Int32? = nil) : Color?
        canvas_width = cw || @last_canvas_w
        canvas_height = ch || @last_canvas_h

        case @shape
        when ColorPickerShape::Cube3D
          raycast_cube(lx, ly, canvas_width, canvas_height)
        when ColorPickerShape::Sphere3D
          raycast_sphere(lx, ly, canvas_width, canvas_height)
        when ColorPickerShape::Circle2D
          raycast_circle(lx, ly, canvas_width, canvas_height)
        when ColorPickerShape::Square2D
          raycast_square(lx, ly, canvas_width, canvas_height)
        end
      end

      # Raycast Cube Surface at (lx, ly)
      def raycast_cube(lx : Int32, ly : Int32, cw : Int32, ch : Int32) : Color?
        center_x = cw // 2
        center_y = ch // 2
        scale = (ch.to_f * 0.32)
        return nil if scale <= 0.0

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        dy_1 = sin_p
        dz_1 = cos_p
        dx_obj = -dz_1 * sin_y
        dy_obj = dy_1
        dz_obj = dz_1 * cos_y

        dy = ly - center_y
        y_c = dy.to_f / scale

        dx = lx - center_x
        x_c = dx.to_f / (scale * 2.0)

        oy_1 = y_c * cos_p - 5.0 * sin_p
        oz_1 = -y_c * sin_p - 5.0 * cos_p
        ox_obj = x_c * cos_y - oz_1 * sin_y
        oy_obj = oy_1
        oz_obj = x_c * sin_y + oz_1 * cos_y

        t_min = -1e9
        t_max = 1e9
        hit = true

        if dx_obj.abs > 1e-6
          t1 = (-1.0 - ox_obj) / dx_obj
          t2 = (1.0 - ox_obj) / dx_obj
          t_near = Math.min(t1, t2)
          t_far = Math.max(t1, t2)
          t_min = Math.max(t_min, t_near)
          t_max = Math.min(t_max, t_far)
        else
          hit = false if ox_obj < -1.0 || ox_obj > 1.0
        end

        if hit
          if dy_obj.abs > 1e-6
            t1 = (-1.0 - oy_obj) / dy_obj
            t2 = (1.0 - oy_obj) / dy_obj
            t_near = Math.min(t1, t2)
            t_far = Math.max(t1, t2)
            t_min = Math.max(t_min, t_near)
            t_max = Math.min(t_max, t_far)
          else
            hit = false if oy_obj < -1.0 || oy_obj > 1.0
          end
        end

        if hit
          if dz_obj.abs > 1e-6
            t1 = (-1.0 - oz_obj) / dz_obj
            t2 = (1.0 - oz_obj) / dz_obj
            t_near = Math.min(t1, t2)
            t_far = Math.max(t1, t2)
            t_min = Math.max(t_min, t_near)
            t_max = Math.min(t_max, t_far)
          else
            hit = false if oz_obj < -1.0 || oz_obj > 1.0
          end
        end

        if hit && t_min <= t_max && t_max > 0.0
          t = t_min > 0.0 ? t_min : t_max
          px = (ox_obj + t * dx_obj).clamp(-1.0, 1.0)
          py = (oy_obj + t * dy_obj).clamp(-1.0, 1.0)
          pz = (oz_obj + t * dz_obj).clamp(-1.0, 1.0)

          r_byte = ((px + 1.0) * 127.5).round.to_u8
          g_byte = ((py + 1.0) * 127.5).round.to_u8
          b_byte = ((pz + 1.0) * 127.5).round.to_u8
          Color.rgb(r_byte, g_byte, b_byte)
        else
          nil
        end
      end

      # Raycast Sphere Surface at (lx, ly)
      def raycast_sphere(lx : Int32, ly : Int32, cw : Int32, ch : Int32) : Color?
        center_x = cw // 2
        center_y = ch // 2
        radius = (ch.to_f * 0.38)
        return nil if radius <= 0.0

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        dy = ly - center_y
        y_c = dy.to_f / radius

        dx = lx - center_x
        x_c = dx.to_f / (radius * 2.0)

        d2 = x_c * x_c + y_c * y_c
        return nil if d2 > 1.0

        z_c = Math.sqrt(1.0 - d2)

        py1 = y_c * cos_p + z_c * sin_p
        pz1 = -y_c * sin_p + z_c * cos_p
        px1 = x_c

        px_obj = px1 * cos_y - pz1 * sin_y
        py_obj = py1
        pz_obj = px1 * sin_y + pz1 * cos_y

        phi = Math.asin(py_obj.clamp(-1.0, 1.0))
        lightness_val = (phi / Math::PI) + 0.5
        theta = Math.atan2(pz_obj, px_obj)
        hue_val = (theta * 180.0 / Math::PI) % 360.0
        hue_val += 360.0 if hue_val < 0.0

        ColorPicker3D.hsl_to_rgb(hue_val, 1.0, lightness_val)
      end

      # Raycast 2D Polar Circle at (lx, ly)
      def raycast_circle(lx : Int32, ly : Int32, cw : Int32, ch : Int32) : Color?
        center_x = cw // 2
        center_y = ch // 2
        radius = (ch.to_f * 0.44)
        return nil if radius <= 0.0

        dy = ly - center_y
        adj_dy = dy.to_f * 2.0
        dx = lx - center_x

        dist = Math.sqrt(dx.to_f * dx.to_f + adj_dy * adj_dy) / (radius * 2.0)
        if dist <= 1.0
          angle = (Math.atan2(adj_dy, dx.to_f) * 180.0 / Math::PI + 360.0) % 360.0
          ColorPicker3D.hsl_to_rgb(angle, dist, @lightness)
        else
          nil
        end
      end

      # Raycast 2D Square Spectrum at (lx, ly)
      def raycast_square(lx : Int32, ly : Int32, cw : Int32, ch : Int32) : Color?
        grid_w = Math.min(cw - 2, 28)
        grid_h = Math.min(ch - 2, 12)
        return nil if grid_w <= 0 || grid_h <= 0

        start_x = (cw - grid_w) // 2
        start_y = (ch - grid_h) // 2

        gx = lx - start_x
        gy = ly - start_y

        if gx >= 0 && gx < grid_w && gy >= 0 && gy < grid_h
          v_ratio = 1.0 - (gy.to_f / grid_h.to_f)
          hue_deg = (gx.to_f / grid_w.to_f) * 360.0
          ColorPicker3D.hsl_to_rgb(hue_deg, v_ratio, @lightness)
        else
          nil
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

        @last_canvas_x = canvas_x
        @last_canvas_y = canvas_y
        @last_canvas_w = canvas_w
        @last_canvas_h = canvas_h

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
        hints = " [Right-Drag] Rotate 3D   [Left-Click] Pick Color   [Wheel] Lightness   [M] Shape   [Space] Auto-Spin "
        buffer.put_string(x, Math.min(foot_y, buffer.height - 1), hints, fg: Color.bright_black)
      end

      # -----------------------------------------------------------------------
      # 3D RGB Cube Rendering (Screen-space Raycasting for 100% Gap-Free Silhouette)
      # -----------------------------------------------------------------------
      private def render_3d_cube(
        buffer : Buffer,
        cx : Int32,
        cy : Int32,
        cw : Int32,
        ch : Int32,
        z_buf : Array(Float64),
      ) : Nil
        center_x = cx + (cw // 2)
        center_y = cy + (ch // 2)
        scale = (ch.to_f * 0.32)

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        # Ray direction in camera space is (0, 0, 1)
        # Transform direction into object space via inverse rotation (-pitch then -yaw):
        dy_1 = sin_p
        dz_1 = cos_p
        dx_obj = -dz_1 * sin_y
        dy_obj = dy_1
        dz_obj = dz_1 * cos_y

        (0...ch).each do |ly|
          sy = cy + ly
          dy = sy - center_y
          y_c = dy.to_f / scale

          (0...cw).each do |lx|
            sx = cx + lx
            dx = sx - center_x
            x_c = dx.to_f / (scale * 2.0) # Aspect ratio compensation

            # Ray origin in camera space: (x_c, y_c, -5.0)
            # Transform origin into object space:
            oy_1 = y_c * cos_p - 5.0 * sin_p
            oz_1 = -y_c * sin_p - 5.0 * cos_p
            ox_obj = x_c * cos_y - oz_1 * sin_y
            oy_obj = oy_1
            oz_obj = x_c * sin_y + oz_1 * cos_y

            # Ray-AABB intersection against [-1, 1]^3
            t_min = -1e9
            t_max = 1e9
            hit = true

            # X slab
            if dx_obj.abs > 1e-6
              t1 = (-1.0 - ox_obj) / dx_obj
              t2 = (1.0 - ox_obj) / dx_obj
              t_near = Math.min(t1, t2)
              t_far = Math.max(t1, t2)
              t_min = Math.max(t_min, t_near)
              t_max = Math.min(t_max, t_far)
            else
              hit = false if ox_obj < -1.0 || ox_obj > 1.0
            end

            # Y slab
            if hit
              if dy_obj.abs > 1e-6
                t1 = (-1.0 - oy_obj) / dy_obj
                t2 = (1.0 - oy_obj) / dy_obj
                t_near = Math.min(t1, t2)
                t_far = Math.max(t1, t2)
                t_min = Math.max(t_min, t_near)
                t_max = Math.min(t_max, t_far)
              else
                hit = false if oy_obj < -1.0 || oy_obj > 1.0
              end
            end

            # Z slab
            if hit
              if dz_obj.abs > 1e-6
                t1 = (-1.0 - oz_obj) / dz_obj
                t2 = (1.0 - oz_obj) / dz_obj
                t_near = Math.min(t1, t2)
                t_far = Math.max(t1, t2)
                t_min = Math.max(t_min, t_near)
                t_max = Math.min(t_max, t_far)
              else
                hit = false if oz_obj < -1.0 || oz_obj > 1.0
              end
            end

            if hit && t_min <= t_max && t_max > 0.0
              t = t_min > 0.0 ? t_min : t_max
              px = (ox_obj + t * dx_obj).clamp(-1.0, 1.0)
              py = (oy_obj + t * dy_obj).clamp(-1.0, 1.0)
              pz = (oz_obj + t * dz_obj).clamp(-1.0, 1.0)

              # Map 3D coordinates [-1, 1] to TrueColor RGB [0, 255]
              r_byte = ((px + 1.0) * 127.5).round.to_u8
              g_byte = ((py + 1.0) * 127.5).round.to_u8
              b_byte = ((pz + 1.0) * 127.5).round.to_u8
              cube_color = Color.rgb(r_byte, g_byte, b_byte)

              buffer.put_char(sx, sy, '█', fg: cube_color)
            end
          end
        end
      end

      # -----------------------------------------------------------------------
      # 3D Color Sphere Rendering (Screen-space Raycasting for 100% Gap-Free Silhouette)
      # -----------------------------------------------------------------------
      private def render_3d_sphere(
        buffer : Buffer,
        cx : Int32,
        cy : Int32,
        cw : Int32,
        ch : Int32,
        z_buf : Array(Float64),
      ) : Nil
        center_x = cx + (cw // 2)
        center_y = cy + (ch // 2)
        radius = (ch.to_f * 0.38)

        cos_y = Math.cos(@yaw)
        sin_y = Math.sin(@yaw)
        cos_p = Math.cos(@pitch)
        sin_p = Math.sin(@pitch)

        (0...ch).each do |ly|
          sy = cy + ly
          dy = sy - center_y
          y_c = dy.to_f / radius

          (0...cw).each do |lx|
            sx = cx + lx
            dx = sx - center_x
            x_c = dx.to_f / (radius * 2.0) # Aspect ratio compensation

            d2 = x_c * x_c + y_c * y_c
            next if d2 > 1.0 # Outside sphere bounds

            z_c = Math.sqrt(1.0 - d2) # Front hemisphere

            # Rotate camera space point (x_c, y_c, z_c) back to object space
            py1 = y_c * cos_p + z_c * sin_p
            pz1 = -y_c * sin_p + z_c * cos_p
            px1 = x_c

            px_obj = px1 * cos_y - pz1 * sin_y
            py_obj = py1
            pz_obj = px1 * sin_y + pz1 * cos_y

            # Compute latitude / longitude on sphere
            phi = Math.asin(py_obj.clamp(-1.0, 1.0))
            lightness_val = (phi / Math::PI) + 0.5
            theta = Math.atan2(pz_obj, px_obj)
            hue_val = (theta * 180.0 / Math::PI) % 360.0
            hue_val += 360.0 if hue_val < 0.0

            sphere_c = ColorPicker3D.hsl_to_rgb(hue_val, 1.0, lightness_val)
            buffer.put_char(sx, sy, '█', fg: sphere_c)
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
      drv.enable_mouse
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
        when Terminal::MouseEvent
          if picker.handle_mouse(event)
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
      drv.disable_mouse
      drv.show_cursor
    end

    result
  end
end
