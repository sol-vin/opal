require "./cast_writer"
require "../src/opal"

# Pure Crystal script that programmatically records Asciinema v2 (.cast) files
# showcasing all major features of the Opal TUI framework.

module Opal
  module Tools
    def self.record_all
      puts "🎬 Recording Opal Asciinema Demos..."

      record_form_wizard
      record_fuzzy_finder
      record_dashboard
      record_autocomplete
      record_cli_toolchain

      puts "✨ All 5 demo casts generated successfully in demos/!"
    end

    # 1. Multi-Field Form Wizard Demo
    def self.record_form_wizard
      cast = CastWriter.new(width: 80, height: 20, title: "Opal Multi-Field Form Wizard")

      # Terminal prompt intro
      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/06_rich_form_wizard.cr\r\n", cps: 20.0)
      cast.pause(0.4)

      # Build form
      form = FormModule::Form.new("New Microservice Configuration")
      f_name = form.text("name", "Service Name:", default: "auth-gateway", required: true)
      f_port = form.text("port", "HTTP Port:", default: "8080")
      f_pass = form.password("api_key", "Cluster Secret Key:", min_length: 6, default: "secret123")
      f_rt = form.select("runtime", "Target Runtime:", ["Crystal 1.15", "Docker Alpine", "Bare Metal"])
      f_feat = form.multi_select("features", "Enabled Features:", ["OpenTelemetry", "Redis Caching", "Rate Limiter", "GraphQL"], selected: ["OpenTelemetry", "Redis Caching"])
      f_dep = form.confirm("deploy_now", "Auto-deploy to staging on save?", default: true)

      form.validate("port") do |val|
        (val.to_i? && (1024..65535).includes?(val.to_i)) ? nil : "Must be a valid port number between 1024 and 65535"
      end

      # Render helper
      render_to_cast = ->(advance : Float64) {
        buf = UI::Buffer.new(78, 18)
        form.render(buf, 0, 0, 78, 18)
        cast.clear_screen(advance: 0.01)
        cast.write(buf.to_s.gsub("\n", "\r\n") + "\r\n", advance: advance)
      }

      # Frame 1: Initial Form
      render_to_cast.call(0.5)

      # Step 1: User types in Service Name
      f_name.value = ""
      f_name.cursor_pos = 0
      "auth-gateway".each_char do |ch|
        f_name.value += ch
        f_name.cursor_pos = f_name.value.size
        render_to_cast.call(0.06)
      end
      cast.pause(0.3)

      # Step 2: Tab to Port field
      form.focus_next
      render_to_cast.call(0.2)

      # Intentionally enter an INVALID port to showcase live inline validation
      f_port.value = "70000"
      f_port.cursor_pos = 5
      render_to_cast.call(0.3)

      # Step 3: Tab to Secret Key (password masked)
      form.focus_next
      render_to_cast.call(0.2)
      f_pass.value = ""
      f_pass.cursor_pos = 0
      "topsecret123".each_char do |ch|
        f_pass.value += ch
        f_pass.cursor_pos = f_pass.value.size
        render_to_cast.call(0.05)
      end
      cast.pause(0.2)

      # Step 4: Tab to Target Runtime (Select with arrow keys)
      form.focus_next
      render_to_cast.call(0.2)
      # Cycle right
      f_rt.selected_idx = 1 # Docker Alpine
      render_to_cast.call(0.35)
      f_rt.selected_idx = 2 # Bare Metal
      render_to_cast.call(0.35)

      # Step 5: Tab to Enabled Features (Multi-select checkboxes)
      form.focus_next
      render_to_cast.call(0.2)
      # Toggle Rate Limiter
      f_feat.sub_cursor = 2
      render_to_cast.call(0.25)
      f_feat.selected.add("Rate Limiter")
      render_to_cast.call(0.35)

      # Step 6: Hit Enter to submit -> Trigger Validation Error!
      form.valid? # Fails because port is 70000!
      render_to_cast.call(0.5)
      cast.pause(0.8) # Notice the red error message under port!

      # Step 7: Correct the port to 8443
      f_port.value = "8443"
      f_port.cursor_pos = 4
      f_port.error = nil
      render_to_cast.call(0.3)
      cast.pause(0.4)

      # Step 8: Submit successfully
      form.valid?
      cast.clear_screen(0.2)
      success_msg = Opal.style.bold.foreground(Opal::Color.green).render("✔ Configuration Captured Successfully!\r\n\r\n")
      cast.write(success_msg, 0.2)

      summary = <<-OUT
        \e[1mService Name   \e[0m: auth-gateway
        \e[1mHTTP Port      \e[0m: 8443
        \e[1mCluster Secret \e[0m: ••••••••••••
        \e[1mTarget Runtime \e[0m: Bare Metal
        \e[1mEnabled Features\e[0m: ["OpenTelemetry", "Redis Caching", "Rate Limiter"]
        \e[1mAuto-deploy    \e[0m: true
      OUT

      cast.write(summary.gsub("\n", "\r\n") + "\r\n", 0.3)
      cast.pause(1.5)

      cast.save("demos/01_form_wizard.cast")
      puts "  ✓ Generated demos/01_form_wizard.cast"
    end

    # 2. Live Fuzzy Finder Demo
    def self.record_fuzzy_finder
      cast = CastWriter.new(width: 80, height: 18, title: "Opal Fuzzy Finder & Split Preview")

      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/07_fuzzy_finder.cr\r\n", cps: 20.0)
      cast.pause(0.3)

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
        "Updated   : 12 minutes ago by sol-vin\n" \
        "Tests     : 124 passed (100%)\n\n" \
        "Press [Enter] to checkout this branch."
      }

      fl = UI::FilterList.new(items: branches, title: "Git Branch Switcher (Fuzzy Finder)", preview_fn: preview_handler)

      render_fl = ->(advance : Float64) {
        buf = UI::Buffer.new(78, 16)
        fl.render(buf, 0, 0, 78, 16)
        cast.clear_screen(advance: 0.01)
        cast.write(buf.to_s.gsub("\n", "\r\n") + "\r\n", advance: advance)
      }

      # Initial view
      render_fl.call(0.4)

      # Type "f"
      fl.append_char('f')
      render_fl.call(0.12)

      # Type "e"
      fl.append_char('e')
      render_fl.call(0.12)

      # Type "a"
      fl.append_char('a')
      render_fl.call(0.12)

      # Type "t"
      fl.append_char('t')
      render_fl.call(0.12)

      # Type "/"
      fl.append_char('/')
      render_fl.call(0.15)

      # Type "f" (filters to feat/fuzzy-finder)
      fl.append_char('f')
      render_fl.call(0.2)
      cast.pause(0.5)

      # Move cursor down
      fl.cursor_down
      render_fl.call(0.3)
      cast.pause(0.4)

      # Select item
      cast.clear_screen(0.2)
      checkout_msg = Opal.style.bold.foreground(Opal::Color.green).render("Switched to branch 'feat/fuzzy-finder'!\r\n")
      cast.write(checkout_msg, 0.3)
      cast.pause(1.5)

      cast.save("demos/02_fuzzy_finder.cast")
      puts "  ✓ Generated demos/02_fuzzy_finder.cast"
    end

    # 3. Cluster Analytics Dashboard Demo
    def self.record_dashboard
      cast = CastWriter.new(width: 80, height: 25, title: "Opal Cluster Analytics Dashboard")

      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/opal\e[0m$ ", 0.0)
      cast.type_text("crystal run examples/08_dataviz_dashboard.cr\r\n", cps: 20.0)
      cast.pause(0.3)

      theme = Theme.get(:catppuccin_mocha)

      # Animate 6 rolling frames
      ratios = [0.45, 0.52, 0.61, 0.68, 0.74, 0.79]
      cpu_trends = [
        [10.0, 12.0, 15.0, 22.0, 35.0, 45.0, 48.0, 42.0, 38.0, 45.0],
        [12.0, 15.0, 22.0, 35.0, 45.0, 48.0, 42.0, 38.0, 45.0, 52.0],
        [15.0, 22.0, 35.0, 45.0, 48.0, 42.0, 38.0, 45.0, 52.0, 61.0],
        [22.0, 35.0, 45.0, 48.0, 42.0, 38.0, 45.0, 52.0, 61.0, 68.0],
        [35.0, 45.0, 48.0, 42.0, 38.0, 45.0, 52.0, 61.0, 68.0, 74.0],
        [45.0, 48.0, 42.0, 38.0, 45.0, 52.0, 61.0, 68.0, 74.0, 79.0],
      ]

      6.times do |i|
        gauge_ratio = ratios[i]
        cpu_data = cpu_trends[i]

        rendered = UI.render(width: 78, height: 23) do |ui|
          ui.box border: :rounded, border_fg: theme.primary, title: "💎 Opal Cluster Analytics", title_fg: theme.accent do |card|
            card.vstack(spacing: 1) do |vs|
              vs.hstack do |hs|
                hs.box(border: :single, border_fg: theme.border, padding: 1, title: "CPU Load Trend") do |b|
                  b.vstack do |v|
                    v.text("Realtime Load:")
                    v.sparkline(cpu_data, color: theme.secondary)
                    pct_str = sprintf("Current: %2d%%", (gauge_ratio * 100).to_i)
                    v.gauge(gauge_ratio, label: pct_str, color: gauge_ratio > 0.7 ? theme.warning : theme.success)
                  end
                end

                hs.box(border: :single, border_fg: theme.border, padding: 1, title: "Memory Allocation (MB)") do |b|
                  b.barchart do |bc|
                    bc.bar("API Worker", 420 + (i * 20), color: theme.success)
                    bc.bar("DB Pool", 850 + (i * 15), color: theme.secondary)
                    bc.bar("Cache Node", 230 - (i * 5), color: theme.info)
                    bc.bar("Background", 1120 + (i * 30), color: theme.danger)
                  end
                end
              end

              vs.box(border: :rounded, border_fg: theme.border, title: "Service Topology") do |b|
                b.tree do |t|
                  t.node("Opal Cluster Gateway", color: theme.primary, icon: "🌐") do |gateway|
                    gateway.add("Authentication Service", color: theme.success, icon: "🔒")
                    gateway.add("Search & Index Service", color: theme.secondary, icon: "🔍") do |search|
                      search.add("Elastic Node 1", color: theme.text_muted, icon: "📦")
                      search.add("Elastic Node 2", color: theme.text_muted, icon: "📦")
                    end
                    gateway.add("Telemetry Agent", color: theme.warning, icon: "📊")
                  end
                end
              end
            end
          end
        end

        cast.clear_screen(advance: 0.01)
        cast.write(rendered.gsub("\n", "\r\n") + "\r\n", advance: i == 0 ? 0.4 : 0.6)
      end

      cast.pause(1.5)
      cast.save("demos/03_cluster_dashboard.cast")
      puts "  ✓ Generated demos/03_cluster_dashboard.cast"
    end

    # 4. Ghost-Text Autocomplete Demo
    def self.record_autocomplete
      cast = CastWriter.new(width: 80, height: 16, title: "Opal Inline Ghost-Text Autocomplete")

      cast.write("\e[1;35m💎 Opal Interactive Shell (v0.1.0)\e[0m\r\n", 0.0)
      cast.write("Type commands with inline ghost-text. Press [Tab] to complete.\r\n\r\n", 0.1)

      engine = Input::Autocomplete.new(["checkout", "commit", "push", "pull", "status", "rebase"])

      # Simulate typing "ch"
      cast.write("opal> ", 0.2)
      cast.write("c", 0.1)
      # Ghost text preview for 'c'
      cast.write("\e[90mheckout\e[0m\e[7D", 0.05) # prints dimmed suffix and moves back 7 chars

      cast.pause(0.25)
      cast.write("\e[0K", 0.0) # clear ghost text
      cast.write("h", 0.08)
      cast.write("\e[90meckout\e[0m\e[6D", 0.05)

      cast.pause(0.35)
      # Hit TAB!
      cast.write("\e[0K", 0.0)
      cast.write("eckout ", 0.08)

      # Type "f"
      cast.write("f", 0.1)
      cast.write("\e[90meat/autocomplete\e[0m\e[17D", 0.05)
      cast.pause(0.3)

      # Hit TAB!
      cast.write("\e[0K", 0.0)
      cast.write("eat/autocomplete", 0.08)
      cast.pause(0.4)

      # Hit Enter
      cast.write("\r\n\e[32m✔ Switched to branch 'feat/autocomplete'\e[0m\r\n\r\n", 0.2)

      # Command 2: status
      cast.write("opal> ", 0.2)
      cast.write("s", 0.1)
      cast.write("\e[90mtatus\e[0m\e[5D", 0.05)
      cast.pause(0.2)
      cast.write("\e[0K", 0.0)
      cast.write("t", 0.1)
      cast.write("\e[90matus\e[0m\e[4D", 0.05)
      cast.pause(0.2)

      # Tab
      cast.write("\e[0K", 0.0)
      cast.write("atus", 0.08)
      cast.pause(0.3)
      cast.write("\r\n", 0.1)

      # Render status output table
      tbl = UI.render(width: 50, height: 5) do |ui|
        ui.table(headers: ["File", "Status"]) do |t|
          t.row(["src/opal/input.cr", "Modified"])
          t.row(["src/opal/form.cr", "Added"])
        end
      end
      cast.write(tbl.gsub("\n", "\r\n") + "\r\n", 0.3)
      cast.pause(1.5)

      cast.save("demos/04_ghost_autocomplete.cast")
      puts "  ✓ Generated demos/04_ghost_autocomplete.cast"
    end

    # 5. CLI Toolchain Demo (Lapis Revamp)
    def self.record_cli_toolchain
      cast = CastWriter.new(width: 80, height: 22, title: "Opal CLI Toolchain & Help Generator")

      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/lapis\e[0m$ ", 0.0)
      cast.type_text("lapis --help\r\n", cps: 20.0)
      cast.pause(0.3)

      # Generate help screen from actual Opal CLI
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
      cast.pause(1.2)

      # Command 2: lapis build --release
      cast.write("\e[1;36msol-vin@terminal\e[0m:\e[1;34m~/lapis\e[0m$ ", 0.3)
      cast.type_text("lapis build --release\r\n", cps: 20.0)
      cast.pause(0.2)

      # Spinner simulation
      spinners = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
      spinners.each_with_index do |s, idx|
        cast.write("\r\e[0K\e[36m#{s}\e[0m Compiling release binary with LLVM optimizations...", 0.08)
      end

      cast.write("\r\e[0K\e[32m✔\e[0m Compilation completed in 1.4s\r\n", 0.2)

      # Progress bar
      mock = Terminal::MockDriver.new
      prog = Prompt::ProgressBar.new(total: 10, bar_width: 25, title: "Linking binary:", driver: mock)
      10.times do |i|
        mock.output_io.clear
        prog.advance(1)
        cast.write(mock.output_io.to_s, 0.08)
      end

      cast.write("\r\n\r\n\e[1;32m🎉 Successfully built bin/lapis (4.2 MB)!\e[0m\r\n", 0.3)
      cast.pause(1.5)

      cast.save("demos/05_cli_toolchain.cast")
      puts "  ✓ Generated demos/05_cli_toolchain.cast"
    end
  end
end

Opal::Tools.record_all
