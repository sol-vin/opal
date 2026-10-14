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

  describe "Declarative link(url, label) & GitHub OSC-8 Helpers" do
    it "supports link(url, label) argument order and optional label" do
      res = Opal.link("https://github.com/sol-vin/opal", "sol-vin/opal")
      res.should eq("\e]8;;https://github.com/sol-vin/opal\e\\sol-vin/opal\e]8;;\e\\")

      # Omitted label defaults to URL
      auto_res = Opal.link("https://github.com/sol-vin/opal")
      auto_res.should eq("\e]8;;https://github.com/sol-vin/opal\e\\https://github.com/sol-vin/opal\e]8;;\e\\")

      # Backward-compatible (label, url) when second argument is a URI
      compat = Opal.link("Crystal Lang", "https://crystal-lang.org")
      compat.should eq("\e]8;;https://crystal-lang.org\e\\Crystal Lang\e]8;;\e\\")
    end

    it "builds GitHub RFC, Discussion, Issue, and PR OSC-8 hyperlinks" do
      rfc = Opal.rfc_link("solvin-ai-org", 119)
      rfc.should eq("\e]8;;https://github.com/sol-vin/solvin-ai-org/discussions/119\e\\RFC #119\e]8;;\e\\")

      issue = Opal.issue_link("sol-vin/opal", 48, "WO-048")
      issue.should eq("\e]8;;https://github.com/sol-vin/opal/issues/48\e\\WO-048\e]8;;\e\\")

      pr = Opal.pr_link("opal", 3)
      pr.should eq("\e]8;;https://github.com/sol-vin/opal/pull/3\e\\PR #3\e]8;;\e\\")

      disc = Opal.discussion_link("solvin-ai-org", 119)
      disc.should eq("\e]8;;https://github.com/sol-vin/solvin-ai-org/discussions/119\e\\Discussion #119\e]8;;\e\\")
    end

    it "parses OSC-8 hyperlink spans from formatted text" do
      raw = "Check #{Opal.rfc_link("solvin-ai-org", 119, id: "rfc-119")} and #{Opal.pr_link("opal", 12)}"
      spans = Opal::Terminal::OSC.parse_links(raw)
      spans.size.should eq(2)
      spans[0].url.should eq("https://github.com/sol-vin/solvin-ai-org/discussions/119")
      spans[0].label.should eq("RFC #119")
      spans[0].id.should eq("rfc-119")
      spans[1].url.should eq("https://github.com/sol-vin/opal/pull/12")
      spans[1].label.should eq("PR #12")
    end

    it "supports fluent Style#link / Style#hyperlink wrapping" do
      styled = Opal::Style.new.bold.fg(:cyan).link("https://github.com/sol-vin/opal", id: "repo").render("Opal Repo")
      styled.should contain("\e]8;id=repo;https://github.com/sol-vin/opal\e\\")
      styled.should contain("Opal Repo")
      styled.should end_with("\e]8;;\e\\")
    end

    it "preserves OSC-8 hyperlinks in Buffer cells and emits them in render_to_string and DiffRenderer" do
      buf = Opal::UI::Buffer.new(30, 2)
      buf.put_link(0, 0, "https://github.com/sol-vin/opal", "Opal TUI")
      buf.put_string(0, 1, "Review #{Opal.rfc_link("solvin-ai-org", 119)} now")

      buf.get(0, 0).char.should eq('O')
      buf.get(0, 0).hyperlink.should eq("https://github.com/sol-vin/opal")
      buf.get(7, 1).char.should eq('R')
      buf.get(7, 1).hyperlink.should eq("https://github.com/sol-vin/solvin-ai-org/discussions/119")
      buf.get(15, 1).hyperlink.should be_nil

      ansi = buf.render_to_string(with_ansi: true)
      ansi.should contain("\e]8;;https://github.com/sol-vin/opal\e\\Opal TUI\e]8;;\e\\")
      ansi.should contain("\e]8;;https://github.com/sol-vin/solvin-ai-org/discussions/119\e\\RFC #119\e]8;;\e\\")

      # Verify DiffRenderer emits OSC-8 sequences on initial and differential renders
      driver = create_mock_driver(30, 2)
      renderer = Opal::UI::DiffRenderer.new(driver)
      renderer.render(buf)
      driver.output.should contain("\e]8;;https://github.com/sol-vin/opal\e\\Opal TUI\e]8;;\e\\")

      # Differential update changing link on row 0
      driver.clear_output
      buf2 = buf.clone
      buf2.put_link(0, 0, "https://github.com/sol-vin/lapis", "Lapis Engine")
      renderer.render(buf2)
      driver.output.should contain("\e]8;;https://github.com/sol-vin/lapis\e\\Lapis Engine\e]8;;\e\\")
    end
  end
end
