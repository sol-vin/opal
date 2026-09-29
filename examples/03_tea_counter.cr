require "../src/opal"

# Example 3: The Elm Architecture (Bubbletea style) Counter & Timer
# Demonstrates pure state transitions, key event handling, and background Cmd.tick timers.

class TimerMsg < Opal::TEA::Msg
  getter time : Time

  def initialize(@time : Time)
  end
end

struct AppModel
  include Opal::TEA::Model

  getter count : Int32
  getter ticks : Int32
  getter? auto_tick : Bool

  def initialize(@count : Int32 = 0, @ticks : Int32 = 0, @auto_tick : Bool = true)
  end

  def init : Opal::TEA::Cmd
    schedule_next_tick
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when TimerMsg
      if @auto_tick
        new_model = AppModel.new(@count, @ticks + 1, @auto_tick)
        {new_model, schedule_next_tick}
      else
        {self, Opal::TEA::Cmd.none}
      end
    when Opal::TEA::KeyMsg
      case msg.key.downcase
      when "+", "up"
        {AppModel.new(@count + 1, @ticks, @auto_tick), Opal::TEA::Cmd.none}
      when "-", "down"
        {AppModel.new(@count - 1, @ticks, @auto_tick), Opal::TEA::Cmd.none}
      when "r"
        {AppModel.new(0, 0, @auto_tick), Opal::TEA::Cmd.none}
      when "space", " "
        toggled = !@auto_tick
        new_cmd = toggled ? schedule_next_tick : Opal::TEA::Cmd.none
        {AppModel.new(@count, @ticks, toggled), new_cmd}
      when "q", "ctrl+c"
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    Opal.render_ui(width: 50, height: 12) do |ui|
      ui.box(border: :rounded, title: "Opal TEA Counter", title_fg: :cyan, padding: 1) do |b|
        b.vstack(spacing: 1) do |v|
          v.hstack(spacing: 2) do
            status_badge = @auto_tick ? v.badge("TICKING", bg: :green, fg: :white) : v.badge("PAUSED", bg: :yellow, fg: :black)
            v.text "Elapsed Ticks: #{@ticks}"
          end
          v.rule
          v.text "Current Counter: #{@count}", fg: :magenta, bold: true
          v.rule
          v.text "Controls: [+/-] Change  [Space] Pause  [r] Reset  [q] Quit", dim: true
        end
      end
    end
  end

  private def schedule_next_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(1.second) do |time|
      TimerMsg.new(time)
    end
  end
end

puts "Launching Opal TEA reactive loop..."
Opal.run_tea(AppModel.new, alt_screen: true)
puts "Exited cleanly! Terminal restored."
