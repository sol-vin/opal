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
end
