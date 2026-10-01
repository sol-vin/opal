require "./cast_writer"
require "../src/opal"

# Pure Crystal script that programmatically records Asciinema v2 (.cast) files
# showcasing all major features of the Opal TUI framework with zero screen flicker,
# rock-solid differential updates, and rich Catppuccin color palettes.

module Opal
  module Tools
    def self.record_all
      puts "[DEMO] Recording Opal Asciinema Demos (Zero-Flicker, Full Color)..."

      record_form_wizard
      record_fuzzy_finder
      record_dashboard
      record_autocomplete
      record_cli_toolchain

      puts "[OK] All 5 demo casts generated successfully in demos/!"
    end

    # 1. Multi-Field Form Wizard Demo
    def self.record_form_wizard
      cast = CastWriter.new(width: 80, height: 20, title: "Opal Multi-Field Form Wizard")

      # Build form model
      form = FormModule::Form.new("New Microservice Configuration")
      f_name = form.text("name", "Service Name:", default: "auth-gateway", required: true)
      f_port = form.text("port", "HTTP Port:", default: "8080")
      f_pass = form.password("api_key", "Cluster Secret Key:", min_length: 6, default: "secret123")
      f_rt = form.select("runtime", "Target Runtime:", ["Crystal 1.15", "Docker Alpine", "Bare Metal"])
      f_feat = form.multi_select("features", "Enabled Features:", ["OpenTelemetry", "Redis Caching", "Rate Limiter", "GraphQL"], selected: ["OpenTelemetry", "Redis Caching"])
      f_dep = form.confirm("deploy_now", "Auto-deploy to staging on save?", default: true)

      form.validate("port") do |val|
        (val.to_i? && (1024..65535).includes?(val.to_i)) ? nil : "Port must be 1024-65535"
      end

      # Initial shell prompt & command invocation
      cast.write("\e[?25h\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/06_rich_form_wizard.cr\r\n", cps: 22.0)
      cast.pause(0.3)

      # Clean clear screen once at startup
      cast.write("\e[2J\e[H\e[?25l", 0.05)

      # Helper for zero-flicker buffer drawing
      render_form = ->(advance : Float64) {
        buf = UI::Buffer.new(78, 18)
        form.render(buf, 0, 0, 78, 18)
        cast.draw_buffer(buf, advance: advance)
      }

      # Frame 1: Initial Form
      render_form.call(0.4)

      # Step 1: Type in Service Name
      f_name.value = ""
      f_name.cursor_pos = 0
      "auth-gateway".each_char do |ch|
        f_name.value += ch
        f_name.cursor_pos = f_name.value.size
        render_form.call(0.06)
      end
      cast.pause(0.3)

      # Step 2: Tab to Port field
      form.focus_next
      render_form.call(0.2)

      # Enter an invalid port to showcase live inline error validation
      f_port.value = "70000"
      f_port.cursor_pos = 5
      render_form.call(0.25)

      # Step 3: Tab to Secret Key (password masked)
      form.focus_next
      render_form.call(0.2)
      f_pass.value = ""
      f_pass.cursor_pos = 0
      "topsecret123".each_char do |ch|
        f_pass.value += ch
        f_pass.cursor_pos = f_pass.value.size
        render_form.call(0.05)
      end
      cast.pause(0.2)

      # Step 4: Tab to Target Runtime (Select with arrows)
      form.focus_next
      render_form.call(0.2)
      f_rt.selected_idx = 1 # Docker Alpine
      render_form.call(0.3)
      f_rt.selected_idx = 2 # Bare Metal
      render_form.call(0.3)

      # Step 5: Tab to Enabled Features (Multi-select checkboxes)
      form.focus_next
      render_form.call(0.2)
      f_feat.sub_cursor = 2
      render_form.call(0.25)
      f_feat.selected.add("Rate Limiter")
      render_form.call(0.3)

      # Step 6: Trigger live validation
      form.valid? # Fails because port 70000 is invalid
      render_form.call(0.4)
      cast.pause(0.8) # Red error message visible under port!

      # Step 7: Correct the port to 8443
      f_port.value = "8443"
      f_port.cursor_pos = 4
      f_port.error = nil
      render_form.call(0.3)
      cast.pause(0.5)

      # Step 8: Final Submission
      form.valid?
      buf_done = UI::Buffer.new(78, 18)
      # Draw success card
      card = UI.build do |ui|
        ui.box(border: :rounded, border_fg: :green, title: "[OK] Microservice Configuration Captured", title_fg: :green) do |b|
          b.vstack(spacing: 1) do |vs|
            vs.text("Service Name   : auth-gateway", bold: true, fg: :white)
            vs.text("HTTP Port      : 8443 (TLS Enabled)", fg: :cyan)
            vs.text("Cluster Secret : ••••••••••••", fg: :white)
            vs.text("Target Runtime : Bare Metal", fg: :yellow)
            vs.text("Features       : OpenTelemetry, Redis Caching, Rate Limiter", fg: :green)
            vs.text("Auto-Deploy    : Enabled (Target: staging-us-east-1)", fg: :magenta)
          end
        end
      end
      card.render(buf_done, 0, 0, 78, 18)
      cast.draw_buffer(buf_done, advance: 0.4)

      # Hold final frame so asciinema captures the rich summary
      cast.pause(3.0)

      cast.save("demos/01_form_wizard.cast")
      puts "  [OK] Generated demos/01_form_wizard.cast"
    end

    # 2. Live Fuzzy Finder Demo
    def self.record_fuzzy_finder
      cast = CastWriter.new(width: 80, height: 18, title: "Opal Fuzzy Finder & Split Preview")

      branches = [
        "main",
        "staging",
        "feat/tea-runtime",
        "feat/diff-renderer",
        "feat/fuzzy-finder",
        "feat/multi-field-form",
        "fix/windows-vt100",
        "fix/buffer-blit-overflow",
        "docs/architecture-guide",
      ]

      preview_handler = ->(branch : String) {
        "Branch Details: #{branch}\n" \
        "──────────────────────────────\n" \
        "Status    : Healthy (Clean tree)\n" \
        "Commits   : 14 ahead of origin/main\n" \
        "Author    : Sol-Vin (lead)\n" \
        "Tests     : 141 passed (100%)\n\n" \
        "Press [Enter] to checkout branch."
      }

      fl = UI::FilterList.new(items: branches, title: "Git Branch Switcher (Fuzzy Finder)", preview_fn: preview_handler)

      # Terminal prompt intro
      cast.write("\e[?25h\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/07_fuzzy_finder.cr\r\n", cps: 22.0)
      cast.pause(0.3)

      # Clear screen once at startup
      cast.write("\e[2J\e[H\e[?25l", 0.05)

      render_fl = ->(advance : Float64) {
        buf = UI::Buffer.new(78, 16)
        fl.render(buf, 0, 0, 78, 16)
        cast.draw_buffer(buf, advance: advance)
      }

      # Initial view
      render_fl.call(0.4)

      # Keystrokes with zero flicker
      "feat/f".each_char do |ch|
        fl.append_char(ch)
        render_fl.call(0.12)
      end
      cast.pause(0.4)

      # Move down arrow
      fl.cursor_down
      render_fl.call(0.3)
      cast.pause(0.5)

      # Press Enter -> Success checkout
      buf_done = UI::Buffer.new(78, 16)
      done_card = UI.build do |ui|
        ui.box(border: :rounded, border_fg: :green, title: "[OK] Git Checkout") do |b|
          b.vstack(spacing: 1) do |v|
            v.text("Switched to branch 'feat/fuzzy-finder'!", bold: true, fg: :green)
            v.text("Your branch is up to date with 'origin/feat/fuzzy-finder'.", fg: :white)
            v.text("Working tree clean (14 commits ahead of main).", fg: :cyan)
          end
        end
      end
      done_card.render(buf_done, 0, 0, 78, 16)
      cast.draw_buffer(buf_done, advance: 0.3)

      cast.pause(3.0)

      cast.save("demos/02_fuzzy_finder.cast")
      puts "  [OK] Generated demos/02_fuzzy_finder.cast"
    end

    # 3. Cluster Analytics Dashboard Demo
    def self.record_dashboard
      cast = CastWriter.new(width: 80, height: 25, title: "Opal Cluster Analytics Dashboard")

      cast.write("\e[?25h\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/08_dataviz_dashboard.cr\r\n", cps: 22.0)
      cast.pause(0.3)

      # Clear screen once at startup
      cast.write("\e[2J\e[H\e[?25l", 0.05)

      theme = Theme.get(:catppuccin_mocha)

      ratios = [0.42, 0.49, 0.58, 0.67, 0.74, 0.81, 0.78]
      cpu_trends = [
        [10.0, 12.0, 15.0, 22.0, 35.0, 42.0, 45.0, 40.0, 38.0, 42.0],
        [12.0, 15.0, 22.0, 35.0, 42.0, 45.0, 40.0, 38.0, 42.0, 49.0],
        [15.0, 22.0, 35.0, 42.0, 45.0, 40.0, 38.0, 42.0, 49.0, 58.0],
        [22.0, 35.0, 42.0, 45.0, 40.0, 38.0, 42.0, 49.0, 58.0, 67.0],
        [35.0, 42.0, 45.0, 40.0, 38.0, 42.0, 49.0, 58.0, 67.0, 74.0],
        [42.0, 45.0, 40.0, 38.0, 42.0, 49.0, 58.0, 67.0, 74.0, 81.0],
        [45.0, 40.0, 38.0, 42.0, 49.0, 58.0, 67.0, 74.0, 81.0, 78.0],
      ]

      ratios.each_with_index do |gauge_ratio, i|
        cpu_data = cpu_trends[i]

        buf = UI::Buffer.new(78, 23)
        element = UI.build do |ui|
          ui.box(border: :rounded, border_fg: theme.primary, title: "[*] Opal Cluster Analytics", title_fg: theme.accent) do |card|
            card.vstack(spacing: 1) do |vs|
              vs.box(border: :single, border_fg: theme.border, padding: 0, title: "CPU Load Trend") do |b|
                b.vstack do |v|
                  v.sparkline(cpu_data, color: theme.secondary)
                  pct_str = sprintf("Current: %2d%%", (gauge_ratio * 100).to_i)
                  v.gauge(gauge_ratio, label: pct_str, color: gauge_ratio > 0.75 ? theme.danger : (gauge_ratio > 0.6 ? theme.warning : theme.success))
                end
              end

              vs.box(border: :single, border_fg: theme.border, padding: 0, title: "Memory Allocation (MB)") do |b|
                b.barchart do |bc|
                  bc.bar("API Worker", 420 + (i * 15), color: theme.success)
                  bc.bar("DB Pool", 850 + (i * 10), color: theme.secondary)
                  bc.bar("Cache Node", 230 - (i * 4), color: theme.info)
                  bc.bar("Background", 1120 + (i * 20), color: theme.danger)
                end
              end

              vs.box(border: :single, border_fg: theme.border, padding: 0, title: "Service Topology") do |b|
                b.tree do |t|
                  t.node("Opal Cluster Gateway", color: theme.primary, icon: "[NET]") do |gateway|
                    gateway.add("Authentication Service", color: theme.success, icon: "[SEC]")
                    gateway.add("Search & Index Service", color: theme.secondary, icon: "[SEARCH]")
                    gateway.add("Telemetry Agent", color: theme.warning, icon: "[VIZ]")
                  end
                end
              end
            end
          end
        end

        element.render(buf, 0, 0, 78, 23)
        cast.draw_buffer(buf, advance: i == 0 ? 0.3 : 0.45)
      end

      cast.pause(3.0)
      cast.save("demos/03_cluster_dashboard.cast")
      puts "  [OK] Generated demos/03_cluster_dashboard.cast"
    end

    # 4. Ghost-Text Autocomplete Demo
    def self.record_autocomplete
      cast = CastWriter.new(width: 80, height: 16, title: "Opal Inline Ghost-Text Autocomplete")

      cast.write("\e[?25h", 0.0)
      cast.write("\e[1;35m[*] Opal Interactive Shell (v0.1.0)\e[0m\r\n", 0.0)
      cast.write("Type commands with inline ghost-text. Press [Tab] to complete.\r\n\r\n", 0.1)

      prompt = "\e[1;36mopal\e[0m \e[1;32m>\e[0m "

      # Command 1: checkout feat/autocomplete
      cast.write(prompt, 0.3)
      cast.pause(0.4)

      # Type 'c'
      cast.write("\r\e[2K#{prompt}c\e[90mheckout\e[0m\e[7D", 0.12)
      cast.pause(0.2)

      # Type 'h'
      cast.write("\r\e[2K#{prompt}ch\e[90meckout\e[0m\e[6D", 0.1)
      cast.pause(0.3)

      # Tab to complete 'checkout '
      cast.write("\r\e[2K#{prompt}\e[1mcheckout\e[0m ", 0.2)
      cast.pause(0.3)

      # Type 'f'
      cast.write("\r\e[2K#{prompt}\e[1mcheckout\e[0m f\e[90meat/autocomplete\e[0m\e[17D", 0.12)
      cast.pause(0.3)

      # Tab to complete branch
      cast.write("\r\e[2K#{prompt}\e[1mcheckout feat/autocomplete\e[0m", 0.2)
      cast.pause(0.4)

      # Enter
      cast.write("\r\n\e[32m[OK] Switched to branch 'feat/autocomplete'\e[0m\r\n\r\n", 0.2)

      # Command 2: status
      cast.write(prompt, 0.25)
      cast.pause(0.3)

      cast.write("\r\e[2K#{prompt}s\e[90mtatus\e[0m\e[5D", 0.12)
      cast.pause(0.2)
      cast.write("\r\e[2K#{prompt}st\e[90matus\e[0m\e[4D", 0.1)
      cast.pause(0.3)

      # Tab
      cast.write("\r\e[2K#{prompt}\e[1mstatus\e[0m", 0.2)
      cast.pause(0.3)
      cast.write("\r\n", 0.15)

      # Render status output table
      tbl = String.build do |io|
        io << "  \e[1;36mFile                Status        Staged\e[0m\r\n"
        io << "  ───────────────────────────────────────────\r\n"
        io << "  \e[33msrc/opal/input.cr\e[0m   Modified      \e[32m[[OK]] Yes\e[0m\r\n"
        io << "  \e[32msrc/opal/form.cr\e[0m    Added         \e[32m[[OK]] Yes\e[0m\r\n"
        io << "  \e[90mexamples/demo.cr\e[0m    Untracked     \e[90m[ ] No\e[0m\r\n"
      end

      cast.write(tbl, 0.3)
      cast.pause(3.0)

      cast.save("demos/04_ghost_autocomplete.cast")
      puts "  [OK] Generated demos/04_ghost_autocomplete.cast"
    end

    # 5. CLI Toolchain Demo (Lapis Revamp)
    def self.record_cli_toolchain
      cast = CastWriter.new(width: 80, height: 22, title: "Opal CLI Toolchain & Help Generator")

      cast.write("\e[?25h\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/lapis\e[0m$ ", 0.0)
      cast.type_text("lapis --help\r\n", cps: 22.0)
      cast.pause(0.3)

      # Generate help screen from Opal CLI
      app = CLI::App.new("lapis", "1.0.0")
      app.description("Modern full-stack Crystal toolchain")
      app.flag(:verbose, "--verbose", "-v", description: "Enable debug logging")
      app.command("build", "Compile application binary") do |cmd|
        cmd.flag(:release, "--release", "-r", description: "Compile with optimizations")
        cmd.option(:target, "--target", "-t", description: "Cross-compilation target")
      end
      app.command("serve", "Start local development server") do |cmd|
        cmd.option(:port, "--port", "-p", description: "HTTP server port", type: :int, default: 3000)
      end
      app.command("test", "Run full test suite")

      help_text = app.help_text("lapis")
      cast.write(help_text.gsub("\n", "\r\n") + "\r\n", 0.2)
      cast.pause(1.8)

      # Command 2: lapis build --release
      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/lapis\e[0m$ ", 0.3)
      cast.type_text("lapis build --release\r\n", cps: 22.0)
      cast.pause(0.3)

      # Spinner simulation
      spinners = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
      15.times do |i|
        s = spinners[i % spinners.size]
        cast.write("\r\e[2K  \e[36m#{s}\e[0m Compiling release binary with LLVM optimizations...", 0.08)
      end

      cast.write("\r\e[2K  \e[32m[OK]\e[0m LLVM codegen completed in 1.2s\r\n\r\n", 0.2)

      # Progress bar
      cast.write("  Linking binary:\r\n", 0.1)
      10.times do |step|
        pct = (step + 1) * 10
        blocks = pct // 5
        bar_fill = "█" * blocks
        bar_empty = "░" * (20 - blocks)
        cast.write("\r\e[2K  [\e[36m#{bar_fill}\e[90m#{bar_empty}\e[0m] \e[1m#{pct}%\e[0m (#{step + 1}/10 objects linked)", 0.1)
      end

      cast.write("\r\n\r\n  \e[1;32m[OK] Successfully built bin/lapis in 2.1s (4.2 MB)!\e[0m\r\n", 0.3)
      cast.pause(3.0)

      cast.save("demos/05_cli_toolchain.cast")
      puts "  [OK] Generated demos/05_cli_toolchain.cast"
    end
  end
end

Opal::Tools.record_all
