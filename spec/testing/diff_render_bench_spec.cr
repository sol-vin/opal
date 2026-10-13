require "../spec_helper"

describe "Ratatui-Style Diff Renderer Verification" do
  it "emits zero terminal output when re-rendering an identical frame (cache hit)" do
    driver = create_mock_driver(80, 24)
    renderer = Opal::UI::DiffRenderer.new(driver)

    buf = Opal::UI::Buffer.new(80, 24)
    buf.put_string(5, 5, "Unchanged Terminal Content")

    # Initial frame
    renderer.render(buf)
    driver.output.should_not be_empty
    driver.clear_output

    # Consecutive identical frame
    renderer.render(buf)
    driver.output.should be_empty # Pure 0-byte dirty cell optimization
  end

  it "emits minimal ANSI sequences when mutating a single cell in a large 80x24 grid" do
    driver = create_mock_driver(80, 24)
    renderer = Opal::UI::DiffRenderer.new(driver)

    buf = Opal::UI::Buffer.new(80, 24)
    buf.fill(0, 0, 80, 24, Opal::UI::Cell.new('.'))

    # Initial full render
    renderer.render(buf)
    initial_bytes = driver.output.bytesize
    initial_bytes.should be > 1000
    driver.clear_output

    # Mutate only one single cell at (40, 12)
    buf.put_char(40, 12, 'X')
    renderer.render(buf)

    delta_output = driver.output
    delta_output.should contain("X")
    # Must only emit cursor jump and single character, well under 25 bytes
    delta_output.bytesize.should be < 30
    delta_output.should_not contain(Opal::Terminal::Screen::CLEAR_ALL)
  end

  it "triggers a full redraw when buffer dimensions are resized" do
    driver = create_mock_driver(40, 10)
    renderer = Opal::UI::DiffRenderer.new(driver)

    buf1 = Opal::UI::Buffer.new(40, 10)
    buf1.put_string(0, 0, "Initial Size")
    renderer.render(buf1)
    driver.clear_output

    # Resize buffer to 60x15
    buf2 = Opal::UI::Buffer.new(60, 15)
    buf2.put_string(0, 0, "Resized Size")
    renderer.render(buf2)

    driver.output.should_not be_empty
    driver.output.should contain("Resized Size")
  end

  it "invalidates cache on demand forcing complete redraw" do
    driver = create_mock_driver(20, 5)
    renderer = Opal::UI::DiffRenderer.new(driver)

    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(0, 0, "Static Text")
    renderer.render(buf)
    driver.clear_output

    # Invalidate cache
    renderer.invalidate!

    # Re-render identical buffer: must re-emit full content
    renderer.render(buf)
    driver.output.should_not be_empty
    driver.output.should contain("Static Text")
  end
end
