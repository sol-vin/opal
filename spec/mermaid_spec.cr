require "./spec_helper"
require "../src/opal/mermaid"

describe "Opal::Mermaid Subsystem" do
  it "parses flowcharts with various node shapes and edge labels" do
    doc = <<-MERMAID
    flowchart TD
      A[Client] -->|HTTPS| B(Gateway)
      B --> C{Authorized?}
      C -->|Yes| D[(Database)]
    MERMAID

    diag = Opal::Mermaid::Parser.parse(doc)
    diag.is_a?(Opal::Mermaid::FlowchartDiagram).should be_true
    fc = diag.as(Opal::Mermaid::FlowchartDiagram)

    fc.nodes.has_key?("A").should be_true
    fc.nodes["A"].shape.should eq(Opal::Mermaid::NodeShape::Rect)
    fc.nodes["B"].shape.should eq(Opal::Mermaid::NodeShape::Round)
    fc.nodes["C"].shape.should eq(Opal::Mermaid::NodeShape::Diamond)
    fc.nodes["D"].shape.should eq(Opal::Mermaid::NodeShape::Database)

    fc.edges.size.should eq(3)
    fc.edges[0].label.should eq("HTTPS")
    fc.edges[2].label.should eq("Yes")
  end

  it "parses sequence diagrams" do
    doc = <<-MERMAID
    sequenceDiagram
      Alice->>Bob: Hello Bob
      Bob-->>Alice: Hi Alice
    MERMAID

    diag = Opal::Mermaid::Parser.parse(doc)
    diag.is_a?(Opal::Mermaid::SequenceDiagramAST).should be_true
    seq = diag.as(Opal::Mermaid::SequenceDiagramAST)
    seq.participants.should eq(["Alice", "Bob"])
    seq.messages.size.should eq(2)
    seq.messages[0].message.should eq("Hello Bob")
    seq.messages[1].dashed?.should be_true
  end

  it "renders diagrams onto a Buffer and integrates with DSL" do
    builder = Opal::UI::Builder.new
    viewer = builder.mermaid_viewer(<<-MERMAID, auto_scroll: true)
    graph LR
      Start[Initialize] --> Finish[Done]
    MERMAID

    viewer.auto_scroll?.should be_true
    buf = Opal::UI::Buffer.new(80, 20)
    viewer.render(buf, 0, 0, 80, 20)

    # Check that some box characters were drawn
    has_box = (0...20).any? do |y|
      (0...80).any? { |x| buf.get(x, y).char == '┌' || buf.get(x, y).char == '─' }
    end
    has_box.should be_true
  end
end
