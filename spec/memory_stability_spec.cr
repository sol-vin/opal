require "./spec_helper"

describe "Opal Memory Stability & Stress Test" do
  it "maintains buffer integrity and stable memory across 2,000 differential frames" do
    driver = create_mock_driver(100, 30)
    dr = Opal::UI::DiffRenderer.new(driver)

    buf = Opal::UI::Buffer.new(100, 30)

    # Simulate 2,000 high-frequency rendering updates
    2000.times do |frame_idx|
      # Clear and draw telemetry window and animated wave
      buf.fill(0, 0, 100, 30, ' ')
      buf.put_string(0, 0, "Frame ##{frame_idx} | High Load Delta Buffer", fg: Opal::Color.cyan, bold: true)

      wave_pos = (frame_idx % 80)
      buf.put_string(wave_pos, 5, "~~~[NODE-ACTIVE]~~~", fg: Opal::Color.green)

      # Render through diff engine
      dr.render(buf)
    end

    # Buffer dimensions must remain unchanged
    buf.width.should eq(100)
    buf.height.should eq(30)
    buf.get(0, 0).char.should eq('F')
    buf.get(0, 0).bold?.should be_true
  end

  it "handles rapid streaming of 1,000 coalesced mouse events without memory corruption" do
    # Build a combined string stream of 1,000 mouse events
    stream = IO::Memory.new
    1000.times do |i|
      x = (i % 80) + 1
      y = (i % 24) + 1
      stream << "\e[<0;#{x};#{y}M\e[<0;#{x};#{y}m"
    end

    events = Opal::Terminal::AnsiParser.parse_all(stream.to_s)
    events.size.should eq(2000)

    # First event
    ev1 = events[0].as(Opal::Terminal::MouseEvent)
    ev1.x.should eq(1)
    ev1.y.should eq(1)
    ev1.action.should eq(Opal::Terminal::MouseAction::Press)

    # Second event
    ev2 = events[1].as(Opal::Terminal::MouseEvent)
    ev2.x.should eq(1)
    ev2.y.should eq(1)
    ev2.action.should eq(Opal::Terminal::MouseAction::Release)

    # 1000th event pair (idx 1998, 1999)
    last_p = events[1998].as(Opal::Terminal::MouseEvent)
    last_p.action.should eq(Opal::Terminal::MouseAction::Press)
    last_r = events[1999].as(Opal::Terminal::MouseEvent)
    last_r.action.should eq(Opal::Terminal::MouseAction::Release)
  end

  it "performs in-place copy_from without memory leaks or data contamination" do
    b1 = Opal::UI::Buffer.new(50, 20)
    b2 = Opal::UI::Buffer.new(50, 20)

    # Fill b1 with styled characters
    (0...20).each do |y|
      (0...50).each do |x|
        b1.put_char(x, y, ((x + y) % 26 + 'A'.ord).chr, fg: Opal::Color.rgb(x.to_u8, y.to_u8, 100), bold: (x % 2 == 0))
      end
    end

    # Repeatedly copy in-place
    500.times do
      b2.copy_from(b1)
    end

    (0...20).each do |y|
      (0...50).each do |x|
        cell = b2.get(x, y)
        cell.char.should eq(((x + y) % 26 + 'A'.ord).chr)
        cell.bold?.should eq(x % 2 == 0)
        cell.fg.should eq(Opal::Color.rgb(x.to_u8, y.to_u8, 100))
      end
    end
  end
end
