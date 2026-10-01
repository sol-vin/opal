require "./spec_helper"

describe "Opal::UI::Group Container" do
  it "strictly clips children within bounds when overflow is :hidden" do
    grp = Opal::UI::Group.new(
      title: "Clipped Box",
      direction: Opal::UI::LayoutDirection::Vertical,
      overflow: Opal::UI::OverflowPolicy::Hidden,
      border: Opal::Border.single
    )

    # Add child that tries to draw a 100-character line
    txt = Opal::UI::Text.new("X" * 100)
    grp.add(txt)

    buf = Opal::UI::Buffer.new(30, 10)
    grp.render(buf, 2, 1, 15, 5)

    # Check border is drawn
    buf.get(2, 1).char.should eq('┌')
    buf.get(16, 1).char.should eq('┐')

    # Inside border (x=3...16), 'X' characters should be drawn
    buf.get(3, 2).char.should eq('X')
    buf.get(15, 2).char.should eq('X')

    # Outside border (x >= 17), should remain clean empty spaces
    buf.get(17, 2).char.should eq(' ')
    buf.get(25, 2).char.should eq(' ')
  end

  it "renders horizontal layouts properly" do
    grp = Opal::UI::Group.new(direction: Opal::UI::LayoutDirection::Horizontal)
    grp.add(Opal::UI::Text.new("ColA"))
    grp.add(Opal::UI::Text.new("ColB"))

    buf = Opal::UI::Buffer.new(20, 5)
    grp.render(buf, 0, 0, 20, 5)

    buf.get(0, 0).char.should eq('C') # ColA at x=0
    buf.get(10, 0).char.should eq('C') # ColB at x=10 (20 // 2)
  end

  it "supports container DSL syntax" do
    builder = Opal::UI::Builder.new
    c = builder.container(title: "Status", border: Opal::Border.rounded) do |b|
      b.text "Active"
    end
    c.title.should eq("Status")
    c.border.should eq(Opal::Border.rounded)
  end
end
