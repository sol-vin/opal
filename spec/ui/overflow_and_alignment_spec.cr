require "../spec_helper"

describe "Opal::UI Buffer Overflows & Misalignments" do
  describe "Coordinate Bounds Checking" do
    it "safely handles negative coordinates without exceptions" do
      buf = Opal::UI::Buffer.new(20, 10)
      buf.fill(-5, -5, 10, 10, 'F')
      buf.put_char(-5, -2, 'X')
      buf.put_char(-1, 0, 'X')
      buf.put_char(0, -1, 'X')
      buf.put_string(-10, -5, "Hello World")
      buf.put_string(-2, 0, "Testing")
      buf.put_line(-5, 1, "Line", 10)

      # First valid cell at (0, 0) should have the clipped remainder of "Testing" ("sting")
      buf.get(0, 0).char.should eq('s')
      buf.get(1, 0).char.should eq('t')
    end

    it "safely handles coordinates beyond buffer width and height" do
      buf = Opal::UI::Buffer.new(20, 10)
      buf.put_char(20, 5, 'Z')
      buf.put_char(25, 15, 'Z')
      buf.put_string(15, 0, "Very long overflow text")
      buf.put_line(18, 1, "Line overflow", 10)
      buf.fill(15, 8, 10, 10, 'B')

      # Check boundary truncation at col 19
      buf.get(19, 0).char.should eq(' ') # from "Very "
      buf.get(19, 1).char.should eq('i') # from "Li"
      buf.get(19, 8).char.should eq('B')
    end

    it "safely handles blit operations with negative or overflowing coordinates" do
      dst = Opal::UI::Buffer.new(20, 10)
      src = Opal::UI::Buffer.new(10, 5)
      src.fill(0, 0, 10, 5, 'X')

      # Blit partially off left/top
      dst.blit(src, -5, -2)
      dst.get(0, 0).char.should eq('X')
      dst.get(4, 2).char.should eq('X')
      dst.get(5, 2).char.should eq(' ') # Outside src blit range

      # Blit partially off right/bottom
      dst.blit(src, 15, 8)
      dst.get(15, 8).char.should eq('X')
      dst.get(19, 9).char.should eq('X')
    end
  end

  describe "Wide Character (CJK / Fullwidth) Alignment" do
    it "replaces wide character with space when it falls on the last column to prevent line wrap" do
      buf = Opal::UI::Buffer.new(10, 5)
      wide_char = '全' # Visual width 2
      buf.put_char(9, 0, wide_char)

      # Col 9 cannot fit wide character + continuation, so it replaces with space
      buf.get(9, 0).char.should eq(' ')
      buf.get(9, 0).continuation?.should be_false
    end

    it "properly sets continuation cell for wide character in interior columns" do
      buf = Opal::UI::Buffer.new(10, 5)
      buf.put_char(4, 0, '全')

      buf.get(4, 0).char.should eq('全')
      buf.get(4, 0).continuation?.should be_false
      buf.get(5, 0).continuation?.should be_true
    end

    it "clears continuation cell if the wide character is overwritten" do
      buf = Opal::UI::Buffer.new(10, 5)
      buf.put_char(2, 0, '全')
      buf.get(3, 0).continuation?.should be_true

      # Overwrite left half with normal char
      buf.put_char(2, 0, 'A')
      buf.get(2, 0).char.should eq('A')
      buf.get(3, 0).char.should eq(' ')
      buf.get(3, 0).continuation?.should be_false
    end

    it "clears the primary wide character cell if its continuation cell is overwritten" do
      buf = Opal::UI::Buffer.new(10, 5)
      buf.put_char(2, 0, '全')
      buf.get(2, 0).char.should eq('全')

      # Overwrite continuation cell directly
      buf.put_char(3, 0, 'B')
      buf.get(3, 0).char.should eq('B')
      # Original cell at 2 should now be cleared
      buf.get(2, 0).char.should eq(' ')
    end
  end

  describe "Clipping Rectangle Protection" do
    it "strictly constrains drawing within with_clip bounds" do
      buf = Opal::UI::Buffer.new(30, 20)

      buf.with_clip(5, 5, 10, 5) do
        buf.fill(0, 0, 30, 20, '#')
        buf.put_string(0, 6, "UNCLIPPED LEAKAGE")
      end

      # Outside clip rectangle must remain empty
      buf.get(4, 5).char.should eq(' ')
      buf.get(15, 5).char.should eq(' ')
      buf.get(5, 4).char.should eq(' ')
      buf.get(5, 10).char.should eq(' ')

      # Inside clip rectangle must be filled
      buf.get(5, 5).char.should eq('#')
      buf.get(14, 9).char.should eq('#')

      # Text must only appear inside clip columns (5..14)
      buf.get(5, 6).char.should eq('P') # Offset 5 into "UNCLIPPED LEAKAGE"
      buf.get(14, 6).char.should eq('A')
      buf.get(15, 6).char.should eq(' ')
    end

    it "correctly intersects nested with_clip calls" do
      buf = Opal::UI::Buffer.new(40, 30)

      buf.with_clip(2, 2, 20, 20) do
        buf.with_clip(5, 5, 10, 10) do
          buf.fill(0, 0, 40, 30, '*')
        end
      end

      # Only (5..14, 5..14) should be '*'
      buf.get(4, 5).char.should eq(' ')
      buf.get(5, 5).char.should eq('*')
      buf.get(14, 14).char.should eq('*')
      buf.get(15, 14).char.should eq(' ')
    end
  end
end
