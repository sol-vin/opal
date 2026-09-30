require "../spec_helper"

describe "Opal::UI Layer & LayerStack Compositing" do
  describe "Layer" do
    it "initializes with correct properties and isolated buffer" do
      layer = Opal::UI::Layer.new(20, 10, x: 5, y: 3, z_index: 100)
      layer.width.should eq(20)
      layer.height.should eq(10)
      layer.x.should eq(5)
      layer.y.should eq(3)
      layer.z_index.should eq(100)
      layer.visible?.should be_true
      layer.transparent_bg?.should be_true
    end

    it "resizes properly while maintaining dimensions" do
      layer = Opal::UI::Layer.new(10, 5)
      layer.buffer.put_char(0, 0, 'A')
      layer.resize(15, 8)
      layer.width.should eq(15)
      layer.height.should eq(8)
      layer.buffer.get(0, 0).char.should eq('A')
    end

    it "blits transparently by default without erasing underlying content" do
      bg_buf = Opal::UI::Buffer.new(20, 10)
      bg_buf.fill(0, 0, 20, 10, '.')

      layer = Opal::UI::Layer.new(10, 5, x: 2, y: 2, transparent_bg: true)
      layer.buffer.put_char(1, 1, 'X')

      layer.blit_to(bg_buf)

      # Unwritten cells in layer must NOT overwrite background '.'
      bg_buf.get(2, 2).char.should eq('.')
      bg_buf.get(3, 3).char.should eq('X') # 2 + 1, 2 + 1
      bg_buf.get(4, 4).char.should eq('.')
    end
  end

  describe "LayerStack" do
    it "composites layers in ascending z-index order" do
      stack = Opal::UI::LayerStack.new
      target = Opal::UI::Buffer.new(20, 10)

      # Create bottom layer
      bottom = stack.create_layer(10, 5, z_index: Opal::UI::LayerStack::TIER_BACKGROUND)
      bottom.buffer.fill(0, 0, 10, 5, 'B')

      # Create middle layer overlapping bottom
      middle = stack.create_layer(10, 5, z_index: Opal::UI::LayerStack::TIER_CONTENT)
      middle.buffer.fill(0, 0, 5, 5, 'M')

      # Create top overlay
      top = stack.create_layer(10, 5, z_index: Opal::UI::LayerStack::TIER_OVERLAYS)
      top.buffer.put_char(0, 0, 'T')

      stack.compose(target)

      # (0, 0) should be 'T' (from top overlay)
      target.get(0, 0).char.should eq('T')
      # (1, 0) should be 'M' (from middle content)
      target.get(1, 0).char.should eq('M')
      # (6, 0) should be 'B' (from bottom background)
      target.get(6, 0).char.should eq('B')
    end

    it "brings layer to front" do
      stack = Opal::UI::LayerStack.new
      l1 = stack.create_layer(10, 5, z_index: 100)
      l2 = stack.create_layer(10, 5, z_index: 200)

      stack.bring_to_front(l1)
      l1.z_index.should be > l2.z_index
    end

    it "sends layer to back" do
      stack = Opal::UI::LayerStack.new
      l1 = stack.create_layer(10, 5, z_index: 100)
      l2 = stack.create_layer(10, 5, z_index: 200)

      stack.send_to_back(l2)
      l2.z_index.should be < l1.z_index
    end
  end
end
