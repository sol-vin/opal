require "../ui/buffer"
require "../style/color"
require "./primitives_2d"

module Opal
  module Graphics
    # 3D Vector for coordinates, directions, and surface normals
    struct Vec3
      getter x : Float64
      getter y : Float64
      getter z : Float64

      def initialize(@x : Float64, @y : Float64, @z : Float64)
      end

      def +(other : Vec3) : Vec3
        Vec3.new(@x + other.x, @y + other.y, @z + other.z)
      end

      def -(other : Vec3) : Vec3
        Vec3.new(@x - other.x, @y - other.y, @z - other.z)
      end

      def *(scalar : Float64) : Vec3
        Vec3.new(@x * scalar, @y * scalar, @z * scalar)
      end

      def dot(other : Vec3) : Float64
        @x * other.x + @y * other.y + @z * other.z
      end

      def cross(other : Vec3) : Vec3
        Vec3.new(
          @y * other.z - @z * other.y,
          @z * other.x - @x * other.z,
          @x * other.y - @y * other.x
        )
      end

      def length : Float64
        Math.sqrt(@x * @x + @y * @y + @z * @z)
      end

      def normalize : Vec3
        len = length
        return Vec3.new(0.0, 0.0, 0.0) if len == 0.0
        Vec3.new(@x / len, @y / len, @z / len)
      end
    end

    # 4x4 Matrix for 3D affine transformations and rotations
    struct Mat4
      getter m : StaticArray(Float64, 16)

      def initialize(vals : StaticArray(Float64, 16))
        @m = vals
      end

      def self.identity : Mat4
        m = StaticArray(Float64, 16).new(0.0)
        m[0] = 1.0; m[5] = 1.0; m[10] = 1.0; m[15] = 1.0
        Mat4.new(m)
      end

      def self.rotation_x(angle : Float64) : Mat4
        c = Math.cos(angle)
        s = Math.sin(angle)
        m = StaticArray(Float64, 16).new(0.0)
        m[0] = 1.0; m[15] = 1.0
        m[5] = c; m[6] = -s
        m[9] = s; m[10] = c
        Mat4.new(m)
      end

      def self.rotation_y(angle : Float64) : Mat4
        c = Math.cos(angle)
        s = Math.sin(angle)
        m = StaticArray(Float64, 16).new(0.0)
        m[5] = 1.0; m[15] = 1.0
        m[0] = c; m[2] = s
        m[8] = -s; m[10] = c
        Mat4.new(m)
      end

      def self.rotation_z(angle : Float64) : Mat4
        c = Math.cos(angle)
        s = Math.sin(angle)
        m = StaticArray(Float64, 16).new(0.0)
        m[10] = 1.0; m[15] = 1.0
        m[0] = c; m[1] = -s
        m[4] = s; m[5] = c
        Mat4.new(m)
      end

      def *(other : Mat4) : Mat4
        res = StaticArray(Float64, 16).new(0.0)
        (0..3).each do |i|
          (0..3).each do |j|
            sum = 0.0
            (0..3).each do |k|
              sum += @m[i * 4 + k] * other.m[k * 4 + j]
            end
            res[i * 4 + j] = sum
          end
        end
        Mat4.new(res)
      end

      def transform(v : Vec3) : Vec3
        x = v.x * @m[0] + v.y * @m[1] + v.z * @m[2] + @m[3]
        y = v.x * @m[4] + v.y * @m[5] + v.z * @m[6] + @m[7]
        z = v.x * @m[8] + v.y * @m[9] + v.z * @m[10] + @m[11]
        Vec3.new(x, y, z)
      end
    end

    # Polygonal face in 3D space with vertex indices and normal
    struct Face3D
      getter indices : Array(Int32)
      getter normal : Vec3
      getter base_color : Color?

      def initialize(@indices : Array(Int32), @normal : Vec3, @base_color : Color? = nil)
      end
    end

    # Parametric 3D mesh container
    class Mesh3DData
      getter name : String
      getter vertices : Array(Vec3)
      getter faces : Array(Face3D)
      getter edges : Array({Int32, Int32})

      def initialize(@name : String, @vertices : Array(Vec3), @faces : Array(Face3D), @edges : Array({Int32, Int32}))
      end

      # Factory: 3D Cube
      def self.cube(size : Float64 = 1.0) : Mesh3DData
        s = size / 2.0
        verts = [
          Vec3.new(-s, -s, -s), # 0
          Vec3.new(s, -s, -s),  # 1
          Vec3.new(s, s, -s),   # 2
          Vec3.new(-s, s, -s),  # 3
          Vec3.new(-s, -s, s),  # 4
          Vec3.new(s, -s, s),   # 5
          Vec3.new(s, s, s),    # 6
          Vec3.new(-s, s, s),   # 7
        ]

        edges = [
          {0, 1}, {1, 2}, {2, 3}, {3, 0},
          {4, 5}, {5, 6}, {6, 7}, {7, 4},
          {0, 4}, {1, 5}, {2, 6}, {3, 7},
        ]

        faces = [
          Face3D.new([0, 1, 2, 3], Vec3.new(0.0, 0.0, -1.0)), # Front
          Face3D.new([5, 4, 7, 6], Vec3.new(0.0, 0.0, 1.0)),  # Back
          Face3D.new([4, 0, 3, 7], Vec3.new(-1.0, 0.0, 0.0)), # Left
          Face3D.new([1, 5, 6, 2], Vec3.new(1.0, 0.0, 0.0)),  # Right
          Face3D.new([3, 2, 6, 7], Vec3.new(0.0, 1.0, 0.0)),  # Top
          Face3D.new([4, 5, 1, 0], Vec3.new(0.0, -1.0, 0.0)), # Bottom
        ]

        Mesh3DData.new("Cube", verts, faces, edges)
      end

      # Factory: 3D UV Sphere
      def self.sphere(radius : Float64 = 1.0, lat_segs : Int32 = 8, lon_segs : Int32 = 12) : Mesh3DData
        verts = [] of Vec3
        edges = [] of {Int32, Int32}
        faces = [] of Face3D

        (0..lat_segs).each do |i|
          theta = i.to_f * Math::PI / lat_segs.to_f
          sin_theta = Math.sin(theta)
          cos_theta = Math.cos(theta)

          (0...lon_segs).each do |j|
            phi = j.to_f * 2.0 * Math::PI / lon_segs.to_f
            x = radius * sin_theta * Math.cos(phi)
            y = radius * cos_theta
            z = radius * sin_theta * Math.sin(phi)
            verts << Vec3.new(x, y, z)
          end
        end

        # Generate edges and faces
        (0...lat_segs).each do |i|
          (0...lon_segs).each do |j|
            p0 = i * lon_segs + j
            p1 = i * lon_segs + ((j + 1) % lon_segs)
            p2 = (i + 1) * lon_segs + ((j + 1) % lon_segs)
            p3 = (i + 1) * lon_segs + j

            edges << {p0, p1}
            edges << {p0, p3}

            v0 = verts[p0]
            norm = v0.normalize
            faces << Face3D.new([p0, p1, p2, p3], norm)
          end
        end

        Mesh3DData.new("Sphere", verts, faces, edges)
      end

      # Factory: 3D Cylinder
      def self.cylinder(radius : Float64 = 1.0, height : Float64 = 2.0, segs : Int32 = 10) : Mesh3DData
        verts = [] of Vec3
        edges = [] of {Int32, Int32}
        faces = [] of Face3D
        half_h = height / 2.0

        # Top circle (0...segs)
        (0...segs).each do |i|
          angle = i.to_f * 2.0 * Math::PI / segs.to_f
          verts << Vec3.new(radius * Math.cos(angle), half_h, radius * Math.sin(angle))
        end

        # Bottom circle (segs...2*segs)
        (0...segs).each do |i|
          angle = i.to_f * 2.0 * Math::PI / segs.to_f
          verts << Vec3.new(radius * Math.cos(angle), -half_h, radius * Math.sin(angle))
        end

        # Side edges & faces
        (0...segs).each do |i|
          nxt = (i + 1) % segs
          top0 = i
          top1 = nxt
          bot0 = segs + i
          bot1 = segs + nxt

          edges << {top0, top1}
          edges << {bot0, bot1}
          edges << {top0, bot0}

          norm = Vec3.new(verts[top0].x, 0.0, verts[top0].z).normalize
          faces << Face3D.new([top0, top1, bot1, bot0], norm)
        end

        Mesh3DData.new("Cylinder", verts, faces, edges)
      end

      # Factory: 3D Pyramid
      def self.pyramid(base_size : Float64 = 1.5, height : Float64 = 1.5) : Mesh3DData
        s = base_size / 2.0
        verts = [
          Vec3.new(0.0, height * 0.6, 0.0), # Apex 0
          Vec3.new(-s, -height * 0.4, -s),  # Base 1
          Vec3.new(s, -height * 0.4, -s),   # Base 2
          Vec3.new(s, -height * 0.4, s),    # Base 3
          Vec3.new(-s, -height * 0.4, s),   # Base 4
        ]

        edges = [
          {1, 2}, {2, 3}, {3, 4}, {4, 1}, # Base
          {0, 1}, {0, 2}, {0, 3}, {0, 4}, # Sides
        ]

        faces = [
          Face3D.new([1, 2, 3, 4], Vec3.new(0.0, -1.0, 0.0)),
          Face3D.new([0, 1, 2], Vec3.new(0.0, 0.5, -1.0).normalize),
          Face3D.new([0, 2, 3], Vec3.new(1.0, 0.5, 0.0).normalize),
          Face3D.new([0, 3, 4], Vec3.new(0.0, 0.5, 1.0).normalize),
          Face3D.new([0, 4, 1], Vec3.new(-1.0, 0.5, 0.0).normalize),
        ]

        Mesh3DData.new("Pyramid", verts, faces, edges)
      end

      # Factory: 3D Torus (Donut)
      def self.torus(
        major_radius : Float64 = 1.2,
        minor_radius : Float64 = 0.45,
        major_segments : Int32 = 12,
        minor_segments : Int32 = 8,
      ) : Mesh3DData
        verts = [] of Vec3
        edges = [] of {Int32, Int32}
        faces = [] of Face3D

        (0...major_segments).each do |i|
          u = i.to_f * 2.0 * Math::PI / major_segments.to_f
          cu = Math.cos(u)
          su = Math.sin(u)

          (0...minor_segments).each do |j|
            v = j.to_f * 2.0 * Math::PI / minor_segments.to_f
            cv = Math.cos(v)
            sv = Math.sin(v)

            x = (major_radius + minor_radius * cv) * cu
            y = minor_radius * sv
            z = (major_radius + minor_radius * cv) * su
            verts << Vec3.new(x, y, z)
          end
        end

        (0...major_segments).each do |i|
          next_i = (i + 1) % major_segments
          (0...minor_segments).each do |j|
            next_j = (j + 1) % minor_segments

            p0 = i * minor_segments + j
            p1 = next_i * minor_segments + j
            p2 = next_i * minor_segments + next_j
            p3 = i * minor_segments + next_j

            edges << {p0, p1}
            edges << {p0, p3}

            norm = (verts[p0] - Vec3.new(major_radius * Math.cos(i.to_f * 2.0 * Math::PI / major_segments.to_f), 0.0, major_radius * Math.sin(i.to_f * 2.0 * Math::PI / major_segments.to_f))).normalize
            faces << Face3D.new([p0, p1, p2, p3], norm)
          end
        end

        Mesh3DData.new("Torus", verts, faces, edges)
      end
    end

    # 3D Mesh Renderer
    module Primitives3D
      SHADING_RAMP = [' ', '.', ':', '-', '=', '+', '*', '#', '%', '@']

      # Renders a 3D mesh into the target terminal buffer
      def self.render_mesh(
        buffer : UI::Buffer,
        mesh : Mesh3DData,
        center_x : Int32,
        center_y : Int32,
        scale : Float64 = 10.0,
        pitch : Float64 = 0.4,
        yaw : Float64 = 0.6,
        roll : Float64 = 0.0,
        wireframe : Bool = false,
        primary_color : Color = Color.cyan,
        light_dir : Vec3 = Vec3.new(0.577, 0.577, -0.577).normalize,
      ) : Nil
        # Build composite rotation matrix: R = Rz * Ry * Rx
        rx = Mat4.rotation_x(pitch)
        ry = Mat4.rotation_y(yaw)
        rz = Mat4.rotation_z(roll)
        rot = rz * (ry * rx)

        # Transform all vertices and project to screen coordinates
        transformed_verts = mesh.vertices.map { |v| rot.transform(v) }
        camera_dist = 4.0

        projected = transformed_verts.map do |v|
          z_persp = camera_dist + v.z
          z_persp = 0.1 if z_persp <= 0.1
          focal = camera_dist / z_persp

          # Compensate for 2:1 character cell aspect ratio
          sx = center_x + (v.x * focal * scale * 2.0).round.to_i
          sy = center_y - (v.y * focal * scale).round.to_i
          {sx, sy, v.z}
        end

        if wireframe
          # Draw edges sorted by average Z (painter's algorithm)
          sorted_edges = mesh.edges.map do |p0, p1|
            avg_z = (transformed_verts[p0].z + transformed_verts[p1].z) / 2.0
            {p0, p1, avg_z}
          end.sort_by(&.[2])

          sorted_edges.each do |p0, p1, _|
            pt0 = projected[p0]
            pt1 = projected[p1]
            Primitives2D.draw_line(buffer, pt0[0], pt0[1], pt1[0], pt1[1], char: '─', fg: primary_color)
          end
        else
          # Solid rasterized / shaded faces
          # Transform face normals and sort faces by average Z
          sorted_faces = mesh.faces.compact_map do |face|
            t_norm = rot.transform(face.normal).normalize

            # Backface culling: dot product with camera view vector (0, 0, -1)
            # If normal.z <= 0, face points away from camera
            next if t_norm.z >= 0.2

            avg_z = face.indices.map { |idx| transformed_verts[idx].z }.sum / face.indices.size.to_f
            {face, t_norm, avg_z}
          end.sort_by(&.[2])

          sorted_faces.each do |face, t_norm, _|
            # Calculate directional lighting intensity
            intensity = Math.max(0.1, -t_norm.dot(light_dir))
            ramp_idx = ((intensity * (SHADING_RAMP.size - 1)).round.to_i).clamp(0, SHADING_RAMP.size - 1)
            shade_char = SHADING_RAMP[ramp_idx]

            shaded_fg = Color.lerp(Color.rgb(30, 40, 60), primary_color, intensity)

            # Rasterize triangular fan of face
            (1...(face.indices.size - 1)).each do |i|
              p0 = projected[face.indices[0]]
              p1 = projected[face.indices[i]]
              p2 = projected[face.indices[i + 1]]

              Primitives2D.fill_triangle(
                buffer,
                p0[0], p0[1],
                p1[0], p1[1],
                p2[0], p2[1],
                char: shade_char,
                fg: shaded_fg
              )
            end
          end
        end
      end
    end
  end
end
