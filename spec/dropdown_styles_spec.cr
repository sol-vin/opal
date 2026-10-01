require "./spec_helper"

describe "Opal::UI::Dropdown Multi-Style & Searchable" do
  it "supports all 6 style presets" do
    classic = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Classic)
    classic.style.should eq(Opal::UI::DropdownStyle::Classic)

    rounded = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Rounded)
    rounded.style.should eq(Opal::UI::DropdownStyle::Rounded)

    minimal = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Minimal)
    minimal.style.should eq(Opal::UI::DropdownStyle::Minimal)

    double = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Double)
    double.style.should eq(Opal::UI::DropdownStyle::Double)

    pill = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Pill)
    pill.style.should eq(Opal::UI::DropdownStyle::Pill)

    searchable = Opal::UI::Dropdown.new(["A", "B"], style: Opal::UI::DropdownStyle::Searchable)
    searchable.style.should eq(Opal::UI::DropdownStyle::Searchable)
  end

  it "renders rounded header brackets" do
    dd = Opal::UI::Dropdown.new(["Production", "Staging"], style: Opal::UI::DropdownStyle::Rounded)
    buf = Opal::UI::Buffer.new(20, 1)
    dd.render(buf, 0, 0, 20, 1)

    buf.get(0, 0).char.should eq('╭')
    buf.get(1, 0).char.should eq('─')
  end

  it "filters items dynamically in searchable mode" do
    items = ["Apple", "Banana", "Cherry", "Avocado"]
    dd = Opal::UI::Dropdown.new(items, style: Opal::UI::DropdownStyle::Searchable, expanded: true)

    # Initial: all items
    dd.filtered_items.size.should eq(4)

    # Type 'a'
    dd.handle_key(Opal::Terminal::KeyEvent.new("a", 'a'))
    # Matches Apple, Banana, Avocado (all contain 'a')
    dd.filtered_items.should eq(["Apple", "Banana", "Avocado"])

    # Type 'v' -> 'av'
    dd.handle_key(Opal::Terminal::KeyEvent.new("v", 'v'))
    dd.filtered_items.should eq(["Avocado"])

    # Backspace
    dd.handle_key(Opal::Terminal::KeyEvent.new("backspace"))
    dd.filtered_items.should eq(["Apple", "Banana", "Avocado"])
  end
end
