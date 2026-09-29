require "./spec_helper"

describe Opal::Prompt do
  describe "Confirm" do
    it "returns true when 'y' is pressed" do
      driver = create_mock_driver
      driver.inject_key("y")

      result = Opal::Prompt::Confirm.run("Proceed?", default: false, driver: driver)
      result.should be_true
    end

    it "returns false when 'n' is pressed" do
      driver = create_mock_driver
      driver.inject_key("n")

      result = Opal::Prompt::Confirm.run("Proceed?", default: true, driver: driver)
      result.should be_false
    end

    it "returns default when enter is pressed" do
      driver1 = create_mock_driver
      driver1.inject_key("enter")
      Opal::Prompt::Confirm.run("Proceed?", default: true, driver: driver1).should be_true

      driver2 = create_mock_driver
      driver2.inject_key("enter")
      Opal::Prompt::Confirm.run("Proceed?", default: false, driver: driver2).should be_false
    end
  end

  describe "Select" do
    it "navigates options with arrow keys and selects with enter" do
      driver = create_mock_driver
      # Move down to second option and hit Enter
      driver.inject_key("down")
      driver.inject_key("enter")

      selected = Opal::Prompt::Select.run(
        question: "Select target",
        options: ["engine", "game", "addon"],
        driver: driver
      )

      selected.should eq("game")
    end

    it "wraps around when moving up from first item" do
      driver = create_mock_driver
      # Up from index 0 wraps to last item
      driver.inject_key("up")
      driver.inject_key("enter")

      selected = Opal::Prompt::Select.run(
        question: "Select target",
        options: ["engine", "game", "addon"],
        driver: driver
      )

      selected.should eq("addon")
    end
  end

  describe "MultiSelect" do
    it "toggles selections with space and submits with enter" do
      driver = create_mock_driver
      # Toggle item 0 (space), move down, toggle item 1 (space), hit enter
      driver.inject_key("space")
      driver.inject_key("down")
      driver.inject_key("space")
      driver.inject_key("enter")

      selected = Opal::Prompt::MultiSelect.run(
        question: "Select features",
        options: ["audio", "physics", "vulkan"],
        driver: driver
      )

      selected.should eq(["audio", "physics"])
    end

    it "selects all items when 'a' is pressed" do
      driver = create_mock_driver
      driver.inject_key("a")
      driver.inject_key("enter")

      selected = Opal::Prompt::MultiSelect.run(
        question: "Select features",
        options: ["audio", "physics", "vulkan"],
        driver: driver
      )

      selected.should eq(["audio", "physics", "vulkan"])
    end
  end

  describe "ProgressBar" do
    it "computes percentage correctly" do
      driver = create_mock_driver
      bar = Opal::Prompt::ProgressBar.new(total: 200, driver: driver)
      bar.percent.should eq(0.0)

      bar.set(50)
      bar.percent.should eq(25.0)

      bar.advance(50)
      bar.percent.should eq(50.0)

      bar.finish
      bar.percent.should eq(100.0)
    end
  end

  describe "Spinner" do
    it "runs block and marks completion" do
      driver = create_mock_driver
      completed = false

      Opal::Prompt::Spinner.start("Building...", driver: driver) do |sp|
        sp.text = "Compiling..."
        completed = true
      end

      completed.should be_true
      driver.output.should contain("Compiling...")
    end
  end
end
