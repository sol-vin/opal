require "./spec_helper"

describe "Opal Command Palette" do
  it "registers actions and category pills" do
    palette = Opal::UI::CommandPalette.new
    called = false
    palette.add("file:save", "Save File", category: "File", shortcut: "ctrl+s") do
      called = true
    end

    palette.actions.size.should eq(1)
    act = palette.actions.first
    act.title.should eq("Save File")
    act.category.should eq("File")
    act.shortcut.should eq("ctrl+s")

    palette.execute_selected
    called.should be_true
  end

  it "filters actions using fuzzy search" do
    palette = Opal::UI::CommandPalette.new
    palette.add("git:commit", "Commit changes", category: "Git")
    palette.add("git:push", "Push branch", category: "Git")
    palette.add("file:open", "Open recent file", category: "File")

    palette.matches.size.should eq(3)

    palette.append_char('p')
    palette.append_char('u')
    palette.query.should eq("pu")

    matches = palette.matches
    matches.first.item.id.should eq("git:push")
  end

  it "renders into buffer" do
    palette = Opal::UI::CommandPalette.new
    palette.add("help", "Show help", category: "General")

    buf = Opal::UI::Buffer.new(50, 10)
    palette.render(buf, 0, 0, 50, 10)

    str = buf.to_s
    str.should contain("Command Palette")
    str.should contain("Show help")
  end

  it "ensures box borders line up perfectly and wide emoji does not push extra chars" do
    palette = Opal::UI::CommandPalette.new
    palette.add("git:commit", "Commit Working Changes", category: "Git", shortcut: "Ctrl+C")
    palette.append_char('g')
    palette.append_char('i')
    palette.append_char('t')
    palette.append_char(' ')
    palette.append_char('c')

    buf = Opal::UI::Buffer.new(70, 14)
    palette.render(buf, 0, 0, 70, 14)

    rendered = buf.render_to_string(with_ansi: false)
    box_lines = rendered.lines.select { |l| l.includes?("│") || l.includes?("╭") || l.includes?("├") || l.includes?("╰") }
    box_lines.should_not be_empty

    # Every border row of the card must end at the exact same visual width
    right_positions = box_lines.map { |l| Opal::VisualWidth.width(l.rstrip) }
    right_positions.uniq.size.should eq(1)
  end
end
