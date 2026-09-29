require "./spec_helper"

describe "Opal OSC Sequences" do
  it "generates OSC 8 hyperlink sequences" do
    link = Opal.hyperlink("Visit Site", "https://crystal-lang.org")
    link.should eq("\e]8;;https://crystal-lang.org\e\\Visit Site\e]8;;\e\\")
  end

  it "generates OSC 8 hyperlink with custom id parameter" do
    link = Opal::Terminal::OSC.hyperlink("Docs", "https://opal.dev", id: "section-1")
    link.should eq("\e]8;id=section-1;https://opal.dev\e\\Docs\e]8;;\e\\")
  end

  it "generates OSC 52 clipboard copy sequences with Base64" do
    seq = Opal::Terminal::OSC.clipboard_copy("hello world")
    seq.should eq("\e]52;c;aGVsbG8gd29ybGQ=\e\\")
  end

  it "writes OSC 52 clipboard copy directly to IO" do
    io = IO::Memory.new
    Opal.copy_to_clipboard("test-copy", io: io)
    io.to_s.should eq("\e]52;c;dGVzdC1jb3B5\e\\")
  end
end
