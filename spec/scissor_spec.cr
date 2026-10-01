require "./spec_helper"

describe "Opal::UI Scissor Mode" do
  it "strictly clips rendering to scissor rectangle" do
    buf = Opal::UI::Buffer.new(30, 10)
    buf.with_scissor(Opal::UI::Rect.new(5, 2, 10, 4)) do
      # Attempt to draw line from 0 to 29 across row 3
      buf.put_line(0, 3, "012345678901234567890123456789", 30)
    end

    # Cells before x=5 must be empty spaces
    (0...5).each do |x|
      buf.get(x, 3).char.should eq(' ')
    end

    # Cells within x=5...15 should contain the characters
    buf.get(5, 3).char.should eq('5')
    buf.get(14, 3).char.should eq('4')

    # Cells from x=15 onward must be empty spaces
    (15...30).each do |x|
      buf.get(x, 3).char.should eq(' ')
    end

    # Rows outside y=2...6 must be empty
    buf.get(5, 1).char.should eq(' ')
    buf.get(5, 6).char.should eq(' ')
  end

  it "computes nested scissor intersections properly" do
    buf = Opal::UI::Buffer.new(40, 20)
    buf.with_scissor(Opal::UI::Rect.new(5, 5, 20, 10)) do
      buf.with_scissor(Opal::UI::Rect.new(10, 8, 20, 10)) do
        # Intersection should be x: 10..24 (w=15), y: 8..14 (h=7)
        buf.fill(0, 0, 40, 20, Opal::UI::Cell.new(char: '#'))
      end
    end

    # Inside intersection: should be '#'
    buf.get(10, 8).char.should eq('#')
    buf.get(24, 14).char.should eq('#')

    # Outside intersection: should be empty space
    buf.get(9, 8).char.should eq(' ')
    buf.get(25, 8).char.should eq(' ')
    buf.get(10, 7).char.should eq(' ')
    buf.get(10, 15).char.should eq(' ')
  end

  it "renders ScissorContainer via DSL and restricts child layout" do
    builder = Opal::UI::Builder.new
    scissor_box = builder.scissor(x: 2, y: 1, width: 8, height: 3) do |b|
      b.text "Very long message exceeding boundaries"
    end

    buf = Opal::UI::Buffer.new(20, 10)
    scissor_box.render(buf, 0, 0, 20, 10)

    # Scissor is at x=2, y=1, w=8, h=3
    # Check that text at x=2 has characters and clipped after x=9
    buf.get(2, 1).char.should eq('V')
    buf.get(9, 1).char.should eq('n') # 8 chars: "Very lon"
    buf.get(10, 1).char.should eq(' ')
    buf.get(1, 1).char.should eq(' ')
  end
end
