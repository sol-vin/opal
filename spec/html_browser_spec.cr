require "./spec_helper"
require "../src/opal/html"

describe "Opal::HTML Subsystem & TUI Browser" do
  it "parses HTML tags into AST nodes" do
    html = <<-HTML
    <h1>Title</h1>
    <p>Paragraph with <a href="https://opal.org">Opal Link</a></p>
    <table>
      <tr><th>Col1</th><th>Col2</th></tr>
    </table>
    HTML

    root = Opal::HTML::Parser.parse(html)
    root.children.size.should be >= 2
    h1 = root.children.find { |c| c.type == Opal::HTML::TagType::H1 }
    h1.should_not be_nil

    link_node = nil
    root.children.each do |c|
      c.children.each do |sub|
        link_node = sub if sub.type == Opal::HTML::TagType::Link
      end
    end
    link_node.should_not be_nil
    link_node.not_nil!.href.should eq("https://opal.org")
  end

  it "tracks back and forward navigation history in HTMLBrowser" do
    browser = Opal::UI::HTMLBrowser.new("about:home")
    browser.url.should eq("about:home")

    browser.navigate_to("about:features")
    browser.url.should eq("about:features")

    browser.back
    browser.url.should eq("about:home")

    browser.forward
    browser.url.should eq("about:features")
  end

  it "renders HTML browser layout and provides DSL helper" do
    builder = Opal::UI::Builder.new
    browser = builder.html_browser("about:opal")
    buf = Opal::UI::Buffer.new(80, 20)
    browser.render(buf, 0, 0, 80, 20)

    # Check top bar
    buf.get(1, 0).char.should eq('[')
    buf.get(2, 0).char.should eq('<')
    buf.get(3, 0).char.should eq(']')

    # Check title rendered
    has_title = (0...20).any? do |y|
      (0...80).any? { |x| buf.get(x, y).char == 'W' } # "Welcome to Opal TUI Browser"
    end
    has_title.should be_true
  end
end
