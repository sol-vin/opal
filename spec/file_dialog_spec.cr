require "./spec_helper"

describe Opal::UI::FileDialog do
  it "loads entries for current directory" do
    dialog = Opal::UI::FileDialog.new(".")
    dialog.entries.should_not be_empty
    # Root or current directory entries should include known files like shard.yml
    names = dialog.entries.map(&.name)
    names.should contain("shard.yml")
    names.should contain("src")
  end

  it "sorts directories before files" do
    dialog = Opal::UI::FileDialog.new(".")
    entries = dialog.entries.reject { |e| e.name == ".." }
    dirs = entries.select(&.directory?)
    files = entries.reject(&.directory?)

    if !dirs.empty? && !files.empty?
      first_dir_idx = entries.index { |e| e.directory? }
      first_file_idx = entries.index { |e| !e.directory? }
      first_dir_idx.should_not be_nil
      first_file_idx.should_not be_nil
      (first_dir_idx.not_nil! < first_file_idx.not_nil!).should be_true
    end
  end

  it "formats file sizes and icons" do
    entry_dir = Opal::UI::FileEntry.new("src", "./src", true)
    entry_dir.display_size.should eq("<DIR>")
    entry_dir.icon.should eq("[DIR]")

    entry_cr = Opal::UI::FileEntry.new("test.cr", "./test.cr", false, size: 2048_i64)
    entry_cr.display_size.should eq("2.0 KB")
    entry_cr.icon.should eq("[CR]")

    entry_bytes = Opal::UI::FileEntry.new("small.txt", "./small.txt", false, size: 100_i64)
    entry_bytes.display_size.should eq("100 B")
    entry_bytes.icon.should eq("[DOC]")
  end

  it "navigates cursor up and down" do
    dialog = Opal::UI::FileDialog.new(".")
    dialog.cursor.should eq(0)

    dialog.cursor_down
    dialog.cursor.should eq(1)

    dialog.cursor_up
    dialog.cursor.should eq(0)

    # Clamping at top
    dialog.cursor_up
    dialog.cursor.should eq(0)
  end

  it "filters entries by query" do
    dialog = Opal::UI::FileDialog.new(".")
    dialog.append_char('s')
    dialog.append_char('h')
    dialog.append_char('a')
    dialog.append_char('r')
    dialog.append_char('d')

    fe = dialog.filtered_entries
    fe.map(&.name).should contain("shard.yml")
  end

  it "renders into a buffer without errors" do
    dialog = Opal::UI::FileDialog.new(".")
    buf = Opal::UI::Buffer.new(70, 30)
    dialog.render(buf, 0, 0, 70, 30)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("Path:")
    rendered.should contain("Filter:")
    rendered.should contain("shard.yml")
  end

  it "filters entries by file extension filters" do
    dialog = Opal::UI::OpenFileDialog.new(".", filters: [".yml"])
    fe = dialog.filtered_entries
    fe.any? { |e| e.name == "shard.yml" }.should be_true
    # Non-directory non-yml files should be excluded
    fe.reject(&.directory?).all? { |e| e.name.ends_with?(".yml") }.should be_true
  end

  it "supports open folder mode" do
    dialog = Opal::UI::OpenFileDialog.new(".", folder_mode: true)
    dialog.mode.should eq(:open_folder)
    dialog.confirm_folder
    dialog.confirmed?.should be_true
    dialog.selected_path.should_not be_nil
  end

  it "handles save file dialog with overwrite protection" do
    dialog = Opal::UI::SaveFileDialog.new(".", default_name: "shard.yml")
    dialog.mode.should eq(:save_file)
    dialog.filename_input.should eq("shard.yml")

    # First attempt to save existing file triggers overwrite warning
    dialog.open_selected
    dialog.overwrite_warning?.should be_true
    dialog.confirmed?.should be_false

    # Second confirmation proceeds
    dialog.open_selected
    dialog.confirmed?.should be_true
    dialog.selected_path.not_nil!.should contain("shard.yml")
  end

  it "handles new file dialog with validation" do
    dialog = Opal::UI::NewFileDialog.new(".", is_folder: false)
    dialog.mode.should eq(:new_file)

    # Empty name fails validation
    dialog.filename_input = ""
    dialog.open_selected
    dialog.confirmed?.should be_false
    dialog.validation_error.should_not be_nil

    # Invalid characters fail validation
    dialog.filename_input = "bad/name.txt"
    dialog.open_selected
    dialog.confirmed?.should be_false

    # Valid name succeeds
    dialog.filename_input = "scratch_test_file.tmp"
    dialog.open_selected
    dialog.confirmed?.should be_true
    dialog.selected_path.not_nil!.should contain("scratch_test_file.tmp")
    File.delete(dialog.selected_path.not_nil!) if File.exists?(dialog.selected_path.not_nil!)
  end

  it "supports mouse click and wheel interactions" do
    dialog = Opal::UI::FileDialog.new(".")
    buf = Opal::UI::Buffer.new(80, 24)
    dialog.render(buf, 0, 0, 80, 24)

    # Wheel down scrolls cursor down
    wheel_down = Opal::Terminal::MouseEvent.new(
      x: 10, y: 5,
      button: Opal::Terminal::MouseButton::WheelDown,
      action: Opal::Terminal::MouseAction::Press
    )
    dialog.handle_mouse(wheel_down).should be_true
    dialog.cursor.should be >= 1

    # Wheel up scrolls cursor back up
    wheel_up = Opal::Terminal::MouseEvent.new(
      x: 10, y: 5,
      button: Opal::Terminal::MouseButton::WheelUp,
      action: Opal::Terminal::MouseAction::Press
    )
    dialog.handle_mouse(wheel_up).should be_true
  end

  it "respects theme colors and styling" do
    dialog = Opal::UI::FileDialog.new(".")
    dialog.with_theme("dracula")
    buf = Opal::UI::Buffer.new(60, 15)
    dialog.render(buf, 0, 0, 60, 15)

    rendered = buf.render_to_string(with_ansi: false)
    rendered.should contain("Path:")
    rendered.should contain("[ Up ]")
    rendered.should contain("[ Open ]")
  end

  it "integrates with DSL builder" do
    output = Opal.render_ui(width: 60, height: 15) do |ui|
      ui.file_dialog(".")
    end
    output.should contain("Path:")
  end
end
