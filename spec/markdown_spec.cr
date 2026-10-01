require "./spec_helper"

describe "Opal Terminal Markdown Viewer" do
  it "renders headers with ANSI styling" do
    md = "# Main Title\n## Sub Title"
    out = Opal.render_markdown(md, width: 40)
    out.should contain("# Main Title")
    out.should contain("## Sub Title")
  end

  it "renders fenced code blocks with language border" do
    md = <<-MD
    ```crystal
    def greet
      puts "hello"
    end
    ```
    MD

    out = Opal.render_markdown(md, width: 50)
    out.should contain("[crystal]")
    out.should contain("def")
    out.should contain("greet")
    out.should contain("┌─")
    out.should contain("└─")
  end

  it "formats inline bold, italic, and code" do
    renderer = Opal::UI::Markdown::Renderer.new(80)
    inline = renderer.format_inline("This is **bold** and *italic* and `code`")
    inline.should contain("\e[1mbold\e[0m")
    inline.should contain("\e[3mitalic\e[0m")
    inline.should contain("\e[36mcode\e[0m")
  end

  it "renders lists and blockquotes" do
    md = "- Item 1\n- Item 2\n> Important quote"
    out = Opal.render_markdown(md, width: 40)
    out.should contain("•")
    out.should contain("Item 1")
    out.should contain("│")
    out.should contain("Important quote")
  end

  it "supports scrollable toggling and auto-scrolling" do
    long_md = (1..50).map { |i| "Line #{i}" }.join("\n")
    viewer = Opal::UI::MarkdownViewer.new(long_md, width: 40, auto_scroll: true, scroll_speed: 2.0)
    viewer.scroll_offset.should eq(0)

    # Tick advances scroll
    viewer.tick(1.0)
    viewer.scroll_offset.should be > 0

    # Disabling scrollable prevents scrolling
    viewer.scrollable = false
    prev_offset = viewer.scroll_offset
    viewer.scroll_down(5)
    viewer.scroll_offset.should eq(prev_offset)
  end

  it "renders AsyncMarkdownViewer throbber then resolved content" do
    async_v = Opal::UI::AsyncMarkdownViewer.new(label: "Fetching docs...") do
      sleep 50.milliseconds
      "# Resolved Doc\nContent here"
    end

    async_v.resolved?.should be_false
    buf = Opal::UI::Buffer.new(40, 10)
    async_v.render(buf, 0, 0, 40, 10)
    buf.to_s.should contain("Fetching docs...")

    # Wait for fiber
    sleep 100.milliseconds
    async_v.resolved?.should be_true
    buf.clear
    async_v.render(buf, 0, 0, 40, 10)
    buf.to_s.should contain("Resolved Doc")
  end
end
