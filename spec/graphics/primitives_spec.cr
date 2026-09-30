require "../spec_helper"
require "../../src/opal/graphics/primitives_2d"
require "../../src/opal/graphics/primitives_3d"

describe "Opal::Graphics Primitives 2D & 3D" do
  describe "Primitives2D" do
    it "draws horizontal, vertical, and diagonal Bresenham lines" do
      buf = Opal::UI::Buffer.new(20, 10)

      # Horizontal line
      Opal::Graphics::Primitives2D.draw_line(buf, 2, 2, 7, 2, char: '=')
      (2..7).each { |x| buf.get(x, 2).char.should eq('=') }

      # Vertical line
      Opal::Graphics::Primitives2D.draw_line(buf, 10, 1, 10, 6, char: '|')
      (1..6).each { |y| buf.get(10, y).char.should eq('|') }

      # Diagonal line
      Opal::Graphics::Primitives2D.draw_line(buf, 0, 0, 4, 4, char: '*')
      (0..4).each { |i| buf.get(i, i).char.should eq('*') }
    end

    it "draws rectangles and drop shadows" do
      buf = Opal::UI::Buffer.new(25, 12)
      Opal::Graphics::Primitives2D.draw_rect(buf, 2, 2, 8, 5, border: :rounded)
      Opal::Graphics::Primitives2D.draw_shadow(buf, 2, 2, 8, 5, shadow_char: '░')

      # Corners
      buf.get(2, 2).char.should eq('╭')
      buf.get(9, 2).char.should eq('╮')
      buf.get(2, 6).char.should eq('╰')
      buf.get(9, 6).char.should eq('╯')

      # Shadow
      buf.get(10, 3).char.should eq('░')
      buf.get(4, 7).char.should eq('░')
    end

    it "draws and fills circles and ellipses" do
      buf = Opal::UI::Buffer.new(30, 15)
      Opal::Graphics::Primitives2D.draw_circle(buf, 15, 7, radius: 4, char: 'O')
      Opal::Graphics::Primitives2D.fill_circle(buf, 15, 7, radius: 2, char: '#')

      # Center should be filled
      buf.get(15, 7).char.should eq('#')
    end

    it "draws and scanline fills triangles" do
      buf = Opal::UI::Buffer.new(20, 10)
      Opal::Graphics::Primitives2D.fill_triangle(buf, 5, 1, 1, 8, 9, 8, char: '▲')

      # Apex and center should be filled
      buf.get(5, 1).char.should eq('▲')
      buf.get(5, 5).char.should eq('▲')
    end
  end

  describe "Primitives3D" do
    it "computes vector arithmetic, dot product, and cross product" do
      v1 = Opal::Graphics::Vec3.new(1.0, 0.0, 0.0)
      v2 = Opal::Graphics::Vec3.new(0.0, 1.0, 0.0)

      v1.dot(v2).should eq(0.0)
      cross = v1.cross(v2)
      cross.x.should eq(0.0)
      cross.y.should eq(0.0)
      cross.z.should eq(1.0)
      cross.length.should eq(1.0)
    end

    it "computes 4x4 matrix rotations and transformations" do
      mat_x = Opal::Graphics::Mat4.rotation_x(0.0)
      v = Opal::Graphics::Vec3.new(1.0, 2.0, 3.0)
      transformed = mat_x.transform(v)
      transformed.x.should be_close(1.0, 0.001)
      transformed.y.should be_close(2.0, 0.001)
      transformed.z.should be_close(3.0, 0.001)
    end

    it "generates parametric 3D meshes" do
      cube = Opal::Graphics::Mesh3DData.cube
      cube.vertices.size.should eq(8)
      cube.faces.size.should eq(6)
      cube.edges.size.should eq(12)

      sphere = Opal::Graphics::Mesh3DData.sphere
      sphere.vertices.size.should be > 20
      sphere.faces.size.should be > 20

      cylinder = Opal::Graphics::Mesh3DData.cylinder
      cylinder.vertices.size.should eq(20)

      pyramid = Opal::Graphics::Mesh3DData.pyramid
      pyramid.vertices.size.should eq(5)

      torus = Opal::Graphics::Mesh3DData.torus
      torus.vertices.size.should be > 20
    end

    it "renders 3D meshes to buffer without errors" do
      buf = Opal::UI::Buffer.new(40, 20)
      cube = Opal::Graphics::Mesh3DData.cube

      # Render wireframe
      Opal::Graphics::Primitives3D.render_mesh(buf, cube, center_x: 20, center_y: 10, scale: 6.0, wireframe: true)

      # Render solid shaded
      buf.clear
      Opal::Graphics::Primitives3D.render_mesh(buf, cube, center_x: 20, center_y: 10, scale: 6.0, wireframe: false)
      # Check that at least some characters are drawn around center
      has_drawn = (-3..3).any? do |dx|
        (-3..3).any? { |dy| buf.get(20 + dx, 10 + dy).char != ' ' }
      end
      has_drawn.should be_true
    end
  end
end
