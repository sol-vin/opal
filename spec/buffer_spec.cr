require "./spec_helper"

describe Opal::UI::Buffer do
  it "initializes all cells to empty spaces" do
    buf = Opal::UI::Buffer.new(10, 5)
    buf.width.should eq(10)
    buf.height.should eq(5)

    (0...5).each do |y|
      (0...10).each do |x|
        cell = buf.get(x, y)
        cell.char.should eq(' ')
        cell.fg.should eq(Opal::Color.none)
        cell.bg.should eq(Opal::Color.none)
        cell.continuation?.should be_false
      end
    end
  end

  it "erases prior content when cleared" do
    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(0, 0, "Test Telemetry", fg: Opal::Color.cyan)
    buf.get(0, 0).char.should eq('T')

    buf.clear
    (0...20).each do |x|
      buf.get(x, 0).char.should eq(' ')
      buf.get(x, 0).fg.should eq(Opal::Color.none)
    end
  end

  it "erases to line width using put_line" do
    buf = Opal::UI::Buffer.new(30, 2)
    buf.put_string(0, 0, "Initial Very Long String Here")
    buf.get(25, 0).char.should eq('H')

    # Overwrite with shorter string padded to width 25
    buf.put_line(0, 0, "Short", width: 25)
    buf.get(0, 0).char.should eq('S')
    buf.get(4, 0).char.should eq('t')
    buf.get(5, 0).char.should eq(' ')
    buf.get(20, 0).char.should eq(' ')
    # Beyond width 25 should still be untouched
    buf.get(26, 0).char.should eq('e')
  end

  it "properly sets and clears continuation cells for wide characters" do
    buf = Opal::UI::Buffer.new(20, 2)
    # Write emoji (width 2) at column 4
    buf.put_char(4, 0, '🔍')
    buf.get(4, 0).char.should eq('🔍')
    buf.get(4, 0).continuation?.should be_false
    buf.get(5, 0).continuation?.should be_true

    # Overwrite column 4 with a 1-width char: continuation cell at 5 must be cleared
    buf.put_char(4, 0, 'a')
    buf.get(4, 0).char.should eq('a')
    buf.get(5, 0).continuation?.should be_false
    buf.get(5, 0).char.should eq(' ')
  end

  it "clears preceding wide char when overwriting its continuation cell" do
    buf = Opal::UI::Buffer.new(20, 2)
    buf.put_char(4, 0, '🚀')
    buf.get(5, 0).continuation?.should be_true

    # Overwriting continuation cell at 5 clears cell 4
    buf.put_char(5, 0, 'b')
    buf.get(4, 0).char.should eq(' ')
    buf.get(4, 0).continuation?.should be_false
    buf.get(5, 0).char.should eq('b')
  end

  it "prevents phantom continuation cells when replacing adjacent wide characters" do
    buf = Opal::UI::Buffer.new(20, 2)
    # Put wide char at 6 (continuation at 7)
    buf.put_char(6, 0, '💎')
    buf.get(7, 0).continuation?.should be_true

    # Now put wide char at 5 (continuation at 6). Old continuation at 7 must be cleared!
    buf.put_char(5, 0, '🔮')
    buf.get(5, 0).char.should eq('🔮')
    buf.get(6, 0).continuation?.should be_true
    buf.get(7, 0).continuation?.should be_false
    buf.get(7, 0).char.should eq(' ')
  end

  it "safely clamps wide characters placed on the last column to prevent line wrap" do
    buf = Opal::UI::Buffer.new(10, 2)
    # Attempt to put 2-width character on column 9 (last column)
    buf.put_char(9, 0, '🔍')
    # Should replace with space rather than writing half a character past bounds
    buf.get(9, 0).char.should eq(' ')
    buf.get(9, 0).continuation?.should be_false
  end

  it "clears sliced continuation cells on fill boundaries" do
    buf = Opal::UI::Buffer.new(20, 4)
    buf.put_char(2, 1, '💎') # cols 2 and 3
    buf.put_char(6, 1, '🔮') # cols 6 and 7

    # Fill rectangle from x=3 to x=6 (touches continuation of 💎 and left of 🔮)
    buf.fill(3, 1, 4, 1, Opal::UI::Cell.empty)

    # Preceding cell 2 must be cleared to prevent orphan wide left half
    buf.get(2, 1).char.should eq(' ')
    # Filled cells should be empty
    (3..6).each do |x|
      buf.get(x, 1).char.should eq(' ')
      buf.get(x, 1).continuation?.should be_false
    end
    # Right cell 7 continuation must be cleared
    buf.get(7, 1).continuation?.should be_false
  end

  it "diff renderer emits clear-to-end-of-line in full_render" do
    driver = create_mock_driver
    dr = Opal::UI::DiffRenderer.new(driver)

    buf = Opal::UI::Buffer.new(20, 2)
    buf.put_string(0, 0, "Hello")
    dr.render(buf)

    # full_render must include \e[K to clear each line and \e[J at end of screen
    driver.output.should contain("\e[0m\e[K")
    driver.output.should contain("\e[J")
  end

  it "diff renderer updates when wide characters change to narrow characters" do
    driver = create_mock_driver
    dr = Opal::UI::DiffRenderer.new(driver)

    # Frame 1: wide character at col 2
    buf1 = Opal::UI::Buffer.new(10, 1)
    buf1.put_char(2, 0, '🔍')
    dr.render(buf1)

    driver.output.should contain("🔍")

    # Frame 2: narrow character at col 2
    buf2 = Opal::UI::Buffer.new(10, 1)
    buf2.put_char(2, 0, 'x')
    dr.render(buf2)

    # Must overwrite col 2 with 'x' and col 3 with ' '
    driver.output.should contain("x")
  end
end
