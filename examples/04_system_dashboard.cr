require "../src/opal"

# Example 4: Full-Screen Live System Dashboard (Ink & Blessed style)
# Demonstrates double-buffered differential rendering with 0% screen flicker,
# live metric updates, tables, and status badges.

struct DashboardState
  include Opal::TEA::Model

  getter cycle : Int32

  def initialize(@cycle : Int32 = 0)
  end

  def init : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(500.milliseconds) { Opal::TEA::TickMsg.new }
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      {DashboardState.new(@cycle + 1), Opal::TEA::Cmd.tick(500.milliseconds) { Opal::TEA::TickMsg.new }}
    when Opal::TEA::KeyMsg
      if msg.matches?("q") || msg.matches?("ctrl+c")
        {self, Opal::TEA::Cmd.quit}
      else
        {self, Opal::TEA::Cmd.none}
      end
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def view : String
    # Calculate mock live metrics
    cpu_percent = (35 + (@cycle * 7) % 55)
    mem_mb = 1200 + (@cycle * 13) % 400

    Opal.render_ui(width: 70, height: 16) do |ui|
      ui.box(border: :rounded, title: "Lapis Toolchain Dashboard", title_fg: :cyan, padding: 1) do |b|
        b.vstack(spacing: 1) do |v|
          # Top header status bar
          v.hstack(spacing: 2) do
            v.badge "ONLINE", bg: :green, fg: :white
            v.text "Godot Host: PID 8412", bold: true
            v.text "CPU: #{cpu_percent}%", fg: cpu_percent > 75 ? :red : :yellow
            v.text "RAM: #{mem_mb} MB", fg: :cyan
          end

          v.rule

          # Process monitor table
          v.table(headers: ["Service", "Role", "Load", "Health"]) do |t|
            t.row ["godot_editor", "Engine Host", "#{cpu_percent // 2}%", "ACTIVE"]
            t.row ["crystal_bridge", "GDExtension", "#{cpu_percent // 3}%", "SYNCHRONIZED"]
            t.row ["lldb_tracer", "Debugger", "2%", "LISTENING"]
            t.row ["asset_bundler", "Packager", "0%", "IDLE"]
          end

          v.rule

          v.hstack(spacing: 2) do
            v.text "Refresh Cycle: #{@cycle}", dim: true
            v.text "Press 'q' to exit", dim: true
          end
        end
      end
    end
  end
end

puts "Starting Full-Screen Dashboard..."
Opal.run_tea(DashboardState.new, alt_screen: true)
puts "Dashboard terminated cleanly."
