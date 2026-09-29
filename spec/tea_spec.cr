require "./spec_helper"

struct CounterModel
  include Opal::TEA::Model

  getter count : Int32

  def initialize(@count : Int32 = 0)
  end

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.none
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::KeyMsg
      case msg.key
      when "+", "up"
        {CounterModel.new(@count + 1), Opal::TEA::Cmd.none}
      when "-", "down"
        {CounterModel.new(@count - 1), Opal::TEA::Cmd.none}
      when "q"
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    "Counter Value: #{@count}"
  end
end

struct AsyncModel
  include Opal::TEA::Model

  getter result : String

  def initialize(@result : String = "initial")
  end

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.perform do
      Opal::TEA::CustomMsg.new("async_loaded")
    end
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::CustomMsg(String)
      {AsyncModel.new(msg.value), Opal::TEA::Cmd.quit}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    "Status: #{@result}"
  end
end

describe Opal::TEA do
  describe "Cmd" do
    it "creates empty and quit commands" do
      none_cmd = Opal::TEA::Cmd.none
      none_cmd.actions.should be_empty
      none_cmd.quit?.should be_false

      quit_cmd = Opal::TEA::Cmd.quit
      quit_cmd.quit?.should be_true
    end

    it "batches multiple commands into one" do
      c1 = Opal::TEA::Cmd.perform { Opal::TEA::TickMsg.new }
      c2 = Opal::TEA::Cmd.quit
      batched = Opal::TEA::Cmd.batch(c1, c2)

      batched.actions.size.should eq(1)
      batched.quit?.should be_true
    end
  end

  describe "Program" do
    it "runs event loop with MockDriver and updates state based on keys" do
      driver = create_mock_driver
      driver.inject_key("+")
      driver.inject_key("+")
      driver.inject_key("+")
      driver.inject_key("-")
      driver.inject_key("q")

      program = Opal::TEA::Program.new(CounterModel.new, driver: driver, alt_screen: false)
      final_model = program.run.as(CounterModel)

      final_model.count.should eq(2)
      driver.stripped_output.should contain("Counter Value: 2")
    end

    it "dispatches async Cmd.perform effects from init" do
      driver = create_mock_driver
      program = Opal::TEA::Program.new(AsyncModel.new, driver: driver, alt_screen: false)
      final_model = program.run.as(AsyncModel)

      final_model.result.should eq("async_loaded")
      driver.stripped_output.should contain("Status: async_loaded")
    end
  end
end
