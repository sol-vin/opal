require "./spec_helper"

describe "Opal::UI::Buffer Region Operations & Transforms" do
  it "copies and crops subregions correctly" do
    buf = Opal::UI::Buffer.new(20, 10)
    buf.put_string(0, 0, "ABCDEFGHIJ")
    buf.put_string(0, 1, "0123456789")

    # Copy 4x2 area starting at (2, 0) -> "CDEF", "2345"
    sub = buf.copy(2, 0, 4, 2)
    sub.width.should eq(4)
    sub.height.should eq(2)
    sub.get(0, 0).char.should eq('C')
    sub.get(3, 0).char.should eq('F')
    sub.get(0, 1).char.should eq('2')
    sub.get(3, 1).char.should eq('5')

    # Crop alias with Rect
    crop_sub = buf.crop(Opal::UI::Rect.new(2, 0, 4, 2))
    crop_sub.get(0, 0).char.should eq('C')
  end

  it "pastes with replace mode and ignore_spaces mode" do
    dst = Opal::UI::Buffer.new(10, 5)
    dst.fill(0, 0, 10, 5, Opal::UI::Cell.new(char: '.'))

    src = Opal::UI::Buffer.new(3, 2)
    src.put_char(0, 0, 'X')
    src.put_char(1, 0, ' ') # space
    src.put_char(2, 0, 'Y')
    src.put_char(0, 1, 'Z')

    # Paste with IgnoreSpaces at (2, 1)
    dst.paste(src, 2, 1, Opal::UI::BlitMode::IgnoreSpaces)

    dst.get(2, 1).char.should eq('X')
    dst.get(3, 1).char.should eq('.') # Space ignored, original '.' preserved
    dst.get(4, 1).char.should eq('Y')
    dst.get(2, 2).char.should eq('Z')

    # Paste with Replace at (5, 1)
    dst.paste(src, 5, 1, Opal::UI::BlitMode::Replace)
    dst.get(5, 1).char.should eq('X')
    dst.get(6, 1).char.should eq(' ') # Space replaced
    dst.get(7, 1).char.should eq('Y')
  end

  it "inverts color attributes within a specified rectangle" do
    buf = Opal::UI::Buffer.new(10, 5)
    fg_col = Opal::Color.rgb(255, 0, 0)
    bg_col = Opal::Color.rgb(0, 0, 255)
    buf.put_char(2, 2, 'K', fg: fg_col, bg: bg_col, reverse: false)

    buf.invert(Opal::UI::Rect.new(2, 2, 1, 1))

    cell = buf.get(2, 2)
    cell.char.should eq('K')
    cell.fg.should eq(bg_col)
    cell.bg.should eq(fg_col)
    cell.reverse?.should be_true
  end

  it "scrolls rectangle contents and clears newly exposed cells" do
    buf = Opal::UI::Buffer.new(10, 10)
    buf.put_line(0, 1, "HELLO", 5)
    buf.put_line(0, 2, "WORLD", 5)

    # Scroll rect down by 2 lines
    buf.scroll_rect(Opal::UI::Rect.new(0, 0, 10, 10), dx: 0, dy: 2, fill_char: ' ')

    buf.get(0, 1).char.should eq(' ')
    buf.get(0, 2).char.should eq(' ')
    buf.get(0, 3).char.should eq('H')
    buf.get(0, 4).char.should eq('W')
  end

  it "rotates buffer by 90 degrees and maps box-drawing glyphs" do
    buf = Opal::UI::Buffer.new(3, 2)
    # Row 0: ┌ ─ ┐
    # Row 1: └ ─ ┘
    buf.put_char(0, 0, '┌')
    buf.put_char(1, 0, '─')
    buf.put_char(2, 0, '┐')
    buf.put_char(0, 1, '└')
    buf.put_char(1, 1, '─')
    buf.put_char(2, 1, '┘')

    rot = buf.rotate_90(clockwise: true)
    rot.width.should eq(2)
    rot.height.should eq(3)

    # In 90 deg clockwise:
    # ┌ becomes ┐
    # ─ becomes │
    # ┐ becomes ┘
    rot.get(1, 0).char.should eq('┐') # Was top-left (0,0) -> in rotated (width-1-y, x) = (2-1-0, 0) = (1, 0)
    rot.get(1, 1).char.should eq('│') # Was '─' at (1, 0)
    rot.get(1, 2).char.should eq('┘') # Was '┐' at (2, 0)
  end

  it "flips buffer horizontally and vertically" do
    buf = Opal::UI::Buffer.new(2, 1)
    buf.put_char(0, 0, '◀')
    buf.put_char(1, 0, '▶')

    flipped_h = buf.flip_h
    flipped_h.get(0, 0).char.should eq('◀') # '▶' flipped h is '◀'
    flipped_h.get(1, 0).char.should eq('▶') # '◀' flipped h is '▶'

    flipped_v = buf.flip_v
    flipped_v.get(0, 0).char.should eq('◀')
  end
end
