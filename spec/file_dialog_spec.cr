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
    buf = Opal::UI::Buffer.new(70, 20)
    dialog.render(buf, 0, 0, 70, 20)
    rendered = buf.render_to_string(with_ansi: false)

    rendered.should contain("Path:")
    rendered.should contain("Filter:")
    rendered.should contain("shard.yml")
  end

  it "integrates with DSL builder" do
    output = Opal.render_ui(width: 60, height: 15) do |ui|
      ui.file_dialog(".")
    end
    output.should contain("Path:")
  end
end
