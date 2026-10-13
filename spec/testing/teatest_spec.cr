require "../spec_helper"

# Model for sequential execution test
class SequenceMsg < Opal::TEA::Msg
  getter step : Int32

  def initialize(@step : Int32)
  end
end

class SequenceModel
  include Opal::TEA::Model
  property history = [] of Int32

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.none
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when SequenceMsg
      @history << msg.step
      if @history.size >= 3
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    "Steps: #{@history.join(",")}"
  end
end

# Model for concurrent message flood test
class IncrementCounterMsg < Opal::TEA::Msg
end

class ConcurrentFloodModel
  include Opal::TEA::Model
  property count : Int32 = 0
  property target : Int32

  def initialize(@target : Int32 = 50)
  end

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.none
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when IncrementCounterMsg
      @count += 1
      if @count >= @target
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    "Count: #{@count}"
  end
end

# Model that raises an exception for panic recovery testing
class ExplodeMsg < Opal::TEA::Msg
end

class PanicModel
  include Opal::TEA::Model

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.none
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when ExplodeMsg
      raise "Intentional crash for terminal panic recovery test"
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    "Alive"
  end
end

describe "Bubbletea Parity Test Suite (Teatest)" do
  describe "Cmd.sequence" do
    it "executes actions strictly in sequential order" do
      order = [] of Int32
      c1 = Opal::TEA::Cmd.perform { order << 1; SequenceMsg.new(1) }
      c2 = Opal::TEA::Cmd.perform { order << 2; SequenceMsg.new(2) }
      c3 = Opal::TEA::Cmd.perform { order << 3; SequenceMsg.new(3) }

      seq_cmd = Opal::TEA::Cmd.sequence(c1, c2, c3)
      seq_cmd.sequence?.should be_true

      model = SequenceModel.new
      tp = teatest(model)
      tp.program.send(SequenceMsg.new(0)) # Warm-up

      # Run the sequence actions directly to assert strict ordering
      seq_cmd.actions.each(&.call)
      order.should eq([1, 2, 3])
      tp.quit
      tp.wait_finished
    end

    it "supports Cmd.every for interval-based timing" do
      ticked = false
      every_cmd = Opal::TEA::Cmd.every(5.milliseconds) do |_t|
        ticked = true
        SequenceMsg.new(99)
      end
      every_cmd.actions.size.should eq(1)
      msg = every_cmd.actions.first.call
      ticked.should be_true
      msg.should be_a(SequenceMsg)
    end
  end

  describe "TestProgram / Teatest Runner" do
    it "injects keys and runs to completion" do
      model = SequenceModel.new
      tp = teatest(model)
      tp.send(SequenceMsg.new(1))
      tp.send(SequenceMsg.new(2))
      tp.send(SequenceMsg.new(3))

      final = tp.wait_finished(timeout: 1.second).as(SequenceModel)
      final.history.should eq([1, 2, 3])
      tp.output.should contain("Steps: 1,2,3")
    end

    it "handles high-concurrency message floods without deadlock or race conditions" do
      target_count = 50
      model = ConcurrentFloodModel.new(target: target_count)
      tp = teatest(model)

      # Concurrently spawn 50 fibers sending messages into the running program
      target_count.times do
        spawn do
          tp.send(IncrementCounterMsg.new)
        end
      end

      final = tp.wait_finished(timeout: 3.seconds).as(ConcurrentFloodModel)
      final.count.should eq(target_count)
      tp.output.should contain("Count: #{target_count}")
    end

    it "supports wait_for polling on terminal output" do
      model = SequenceModel.new
      tp = teatest(model)

      spawn do
        sleep 10.milliseconds
        tp.send(SequenceMsg.new(10))
        tp.send(SequenceMsg.new(20))
        tp.send(SequenceMsg.new(30))
      end

      tp.wait_for(timeout: 1.second) { |text| text.includes?("Steps: 10,20,30") }
      tp.wait_finished(timeout: 1.second)
    end

    it "times out cleanly when program does not terminate" do
      model = SequenceModel.new
      tp = teatest(model)

      expect_raises(Opal::Testing::TimeoutError) do
        tp.wait_finished(timeout: 50.milliseconds)
      end

      tp.quit
      tp.wait_finished(timeout: 1.second)
    end

    it "safely restores terminal attributes upon crash or panic" do
      model = PanicModel.new
      driver = create_mock_driver
      program = Opal::TEA::Program.new(model, driver: driver, alt_screen: true, mouse_enabled: true)

      expect_raises(Exception, /Intentional crash/) do
        spawn { program.send(ExplodeMsg.new) }
        program.run
      end

      # Terminal attributes MUST be safely restored so user terminal is never corrupted
      driver.in_raw_mode?.should be_false
      driver.alt_screen?.should be_false
      driver.mouse_enabled?.should be_false
      driver.cursor_visible?.should be_true
      program.error.should_not be_nil
    end
  end
end
