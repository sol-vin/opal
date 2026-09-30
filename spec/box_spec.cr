require "./spec_helper"

describe Opal::UI::Box do
  it "fills opaque background color over buffer" do
    buf = Opal::UI::Buffer.new(10, 5)
    # Paint buffer with green dots
    buf.fill(0, 0, 10, 5, '.', Opal::Color.green, Opal::Color.black)

    # Place opaque box on top with dark blue background
    dark_blue = Opal::Color.rgb(10, 20, 30)
    box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("Hi", fg: Opal::Color.white),
      border: :rounded,
      bg: dark_blue
    )
    box.render(buf, 2, 1, 6, 3)

    # Outside the box remains green dots
    buf.get(0, 0).char.should eq('.')

    # Inside the box is filled with dark_blue
    inner_cell = buf.get(4, 2)
    inner_cell.bg.should eq(dark_blue)

    # Border cells also have dark_blue background
    corner = buf.get(2, 1)
    corner.bg.should eq(dark_blue)
  end

  it "preserves box background for child text elements" do
    buf = Opal::UI::Buffer.new(12, 5)
    bg_color = Opal::Color.rgb(18, 22, 34)

    box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("Opal", fg: Opal::Color.cyan),
      border: :rounded,
      bg: bg_color
    )
    box.render(buf, 1, 1, 10, 3)

    # The text 'O' at (2, 2) should have fg cyan and bg rgb(18, 22, 34)
    text_cell = buf.get(2, 2)
    text_cell.char.should eq('O')
    text_cell.fg.should eq(Opal::Color.cyan)
    text_cell.bg.should eq(bg_color)
  end
end
