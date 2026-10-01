require "../spec_helper"

class CustomViewTest
  include Opal::DSL

  def build_card : Opal::UI::Element
    Opal::UI.build do
      box(title: "User Card", border: :rounded) do
        vstack do
          text "User: Alice"
          badge "ADMIN", bg: :blue
        end
      end
    end
  end
end

describe Opal::UI::DSL do
  describe "Builder & StackBuilder Feature Parity" do
    it "supports all core visual components in Builder and StackBuilder" do
      ui = Opal::UI.build do
        text "Header", fg: :cyan
        badge "ACTIVE", bg: :green
        rule
        box(title: "Main Box") do
          vstack(spacing: 1) do
            text "Inside Stack"
            badge "NESTED"
            rule '-'
            sparkline [1.0, 2.0, 3.0]
            gauge 0.5, label: "50%"
            table(headers: ["A", "B"]) do
              row ["1", "2"]
            end
          end
        end
      end

      ui.should_not be_nil
      ui.is_a?(Opal::UI::Element).should be_true
    end

    it "supports all previously missing interactive widgets inside vstack and hstack" do
      stack = Opal::UI.build do
        vstack(spacing: 1) do
          button "Click Me", style: :primary
          dropdown ["Option 1", "Option 2"]
          scrollbar length: 10, total: 50
          switch "Live Toggle", on: true
          checkbox "Agree", checked: true
          slider min: 0.0, max: 10.0, value: 5.0
          radio_set ["A", "B", "C"]
          digits "123"
          rich_log max_lines: 50
          loading_indicator "Spinning", style: :dots
          header title: "App Header"
          footer
          placeholder "Area"
        end
      end

      stack.is_a?(Opal::UI::VStack).should be_true
      stack.children.size.should eq(13)
    end
  end

  describe "Multipurpose Mode Blending" do
    it "allows inserting pre-instantiated widgets into DSL trees using add, <<, and custom" do
      my_table = Opal::UI::Table.new(headers: ["Col1", "Col2"])
      my_table.row(["Val1", "Val2"])
      my_btn = Opal::UI::Button.new("Submit")
      my_gauge = Opal::UI::Gauge.new(0.75, label: "75%")

      tree = Opal::UI.build do
        vstack do |v|
          text "Pre-instantiated elements below:"
          add my_table
          v << my_btn
          custom my_gauge
        end
      end

      tree.is_a?(Opal::UI::VStack).should be_true
      tree.children.size.should eq(4)
      tree.children[1].should eq(my_table)
      tree.children[2].should eq(my_btn)
      tree.children[3].should eq(my_gauge)
    end

    it "allows box to take an existing child element in traditional mode" do
      my_text = Opal::UI::Text.new("Pre-built text")
      b = Opal::UI.build do
        box(title: "Wrapped", child: my_text)
      end

      b.is_a?(Opal::UI::Box).should be_true
      b.as(Opal::UI::Box).child.should eq(my_text)
    end

    it "allows Box.new to accept a declarative DSL block" do
      b = Opal::UI::Box.new(title: "Block Box", border: :rounded) do
        vstack(spacing: 0) do
          text "First line"
          text "Second line"
        end
      end

      b.title.should eq("Block Box")
      b.child.should_not be_nil
      b.child.is_a?(Opal::UI::VStack).should be_true
    end

    it "allows VStack and HStack to accept Enumerable of elements" do
      elements = [Opal::UI::Text.new("A"), Opal::UI::Text.new("B")]
      v = Opal::UI::VStack.new(elements, spacing: 2)
      h = Opal::UI::HStack.new(elements, spacing: 1)

      v.children.size.should eq(2)
      h.children.size.should eq(2)
      v.spacing.should eq(2)
      h.spacing.should eq(1)
    end

    it "allows VStack and HStack to accept a declarative DSL block" do
      v = Opal::UI::VStack.new(spacing: 1) do
        text "Item 1"
        text "Item 2"
        badge "NEW"
      end

      v.children.size.should eq(3)
      v.children[0].is_a?(Opal::UI::Text).should be_true
      v.children[2].is_a?(Opal::UI::Badge).should be_true
    end

    it "allows Screen and ModalScreen to be instantiated with a DSL block" do
      screen = Opal::UI::Screen.new("dashboard", "System Dashboard") do
        box(title: "Overview") do
          text "Active Nodes: 12"
        end
      end

      screen.name.should eq("dashboard")
      screen.title.should eq("System Dashboard")
      screen.root.should_not be_nil
      screen.root.is_a?(Opal::UI::Box).should be_true

      modal = Opal::UI::ModalScreen.new("confirm", "Confirm Action") do
        modal title: "Prompt", message: "Proceed?", buttons: ["Yes", "No"]
      end

      modal.name.should eq("confirm")
      modal.root.is_a?(Opal::UI::Modal).should be_true
    end

    it "allows Screen to be composed or re-composed with compose method" do
      screen = Opal::UI::Screen.new("home")
      screen.root.should be_nil

      screen.compose do
        vstack do
          header title: "Title"
          footer
        end
      end

      screen.root.should_not be_nil
      screen.root.is_a?(Opal::UI::VStack).should be_true
    end

    it "allows any custom class to include Opal::UI::DSL or Opal::DSL" do
      card = CustomViewTest.new.build_card
      card.is_a?(Opal::UI::Box).should be_true
    end
  end

  describe "Dual-Mode Blocks (Implicit and Explicit Receivers)" do
    it "evaluates implicit receiver blocks cleanly" do
      rendered = Opal.render_ui(width: 40, height: 6) do
        box(border: :rounded, title: "Implicit") do
          vstack do
            text "Line A"
            text "Line B"
          end
        end
      end

      rendered.should contain("Implicit")
      rendered.should contain("Line A")
      rendered.should contain("Line B")
    end

    it "evaluates explicit receiver blocks with full backward compatibility" do
      rendered = Opal.render_ui(width: 40, height: 6) do |ui|
        ui.box(border: :rounded, title: "Explicit") do |b|
          b.vstack do |v|
            v.text "Explicit Line A"
            v.text "Explicit Line B"
          end
        end
      end

      rendered.should contain("Explicit")
      rendered.should contain("Explicit Line A")
      rendered.should contain("Explicit Line B")
    end
  end
end
