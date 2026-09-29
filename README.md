<div align="center">

# 💎 Opal

**Next-Generation Terminal User Interface (TUI) & CLI DSL Framework for Crystal**

[![CI](https://github.com/sol-vin/opal/actions/workflows/ci.yml/badge.svg)](https://github.com/sol-vin/opal/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue.svg)](https://sol-vin.github.io/opal/)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.8.0-black.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*Pure Crystal. Zero external C library dependencies (no ncurses). Native Windows, Linux, and macOS support.*

</div>

---

## 🌟 What is Opal?

**Opal** is an all-in-one terminal framework for [Crystal](https://crystal-lang.org) designed to build world-class command-line interfaces, micro-interactive prompts, and full-screen terminal applications.

It merges the best paradigms from modern terminal engineering into a cohesive, idiomatic Crystal DSL:
- 🍵 **The Elm Architecture (TEA)** — Pure, predictable state management inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
- 🎨 **Declarative Fluent Styling & Themes** — Lipgloss-inspired composable styling, borders, 24-bit TrueColor, visual string width, and curated themes (Catppuccin, Dracula, TokyoNight, Nord, Gruvbox).
- ⚡ **Flicker-Free Delta Rendering** — Blessed-inspired double buffering that computes minimal character delta updates for 60fps full-screen performance.
- 🛠️ **Expressive CLI App DSL** — Clap/Commander-style subcommands, typed flags, choices, global flag propagation, and shell completion (`bash`, `zsh`, `fish`).
- 📝 **Multi-Field Form & Wizard DSL** — All fields visible simultaneously, tab navigation, live inline validation, and instant submission.
- 🔍 **Live Fuzzy Search & Filter** — Instant keystroke matching with rune highlighting and split preview pane (`Opal.filter`).
- 📊 **Rich Data Visualizations** — Unicode block Sparklines, horizontal/vertical BarCharts, percentage Gauges, and hierarchical Trees.
- 🪟 **Layer Blending, Modals & Toasts** — Buffer `blit`, backdrop dimming, centered confirmation dialogs, and non-blocking toast queues.
- 📖 **Terminal Markdown Viewer** — Styled headers, blockquotes, lists, and syntax colorized code blocks.
- 🔮 **Ghost-Text Autocomplete & Input DSL** — Modern fish/zsh-style inline ghost text autocomplete on `Tab`, flexible interactive line editing, and declarative key bindings.
- 🖱️ **Hit-Test Mouse Routing DSL** — SGR extended mouse tracking with declarative click, drag, and scroll zones.
- 🔗 **OSC 8 Links & OSC 52 Clipboard** — Native clickable terminal hyperlinks and desktop clipboard copying across SSH and local sessions.

---

## 📦 Installation

Add Opal to your project's `shard.yml`:

```yaml
dependencies:
  opal:
    github: sol-vin/opal
    version: ~> 0.1.0
```

Then install dependencies:

```bash
shards install
```

Require Opal in your Crystal code:

```crystal
require "opal"
```

---

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Architecture Overview](#-architecture-overview)
- [Multi-Field Form & Wizard DSL](#-multi-field-form--wizard-dsl)
- [Live Fuzzy Search & Filter](#-live-fuzzy-search--filter)
- [Data Visualizations](#-data-visualizations)
- [Buffer Blitting, Modals & Toasts](#-buffer-blitting-modals--toasts)
- [Terminal Markdown Viewer](#-terminal-markdown-viewer)
- [Theme Engine & Semantic Colors](#-theme-engine--semantic-colors)
- [Command Palette Overlay](#-command-palette-overlay)
- [OSC 8 Hyperlinks & OSC 52 Clipboard](#-osc-8-hyperlinks--osc-52-clipboard)
- [Animation & Easing Engine](#-animation--easing-engine)
- [CLI Application DSL](#-cli-application-dsl)
- [Fluent Styling & Layout](#-fluent-styling--layout)
- [Interactive Prompts](#-interactive-prompts)
- [Autocomplete & Ghost Text DSL](#-autocomplete--ghost-text-dsl)
- [KeyMap & MouseMap DSLs](#-keymap--mousemap-dsls)
- [The Elm Architecture (TEA)](#-the-elm-architecture-tea)
- [Testing with MockDriver](#-testing-with-mockdriver)
- [Examples](#-examples)
- [License](#-license)

---

## 🚀 Quick Start

### 1. Build an Interactive Setup Wizard with `Opal.form`

```crystal
require "opal"

result = Opal.form("Project Setup") do |f|
  f.text "name", "Project Name:", default: "my-app", required: true
  f.password "token", "API Token:", min_length: 8
  f.select "db", "Database:", ["PostgreSQL", "SQLite", "MySQL"]
  f.multi_select "addons", "Addons:", ["Redis", "Elasticsearch", "GraphQL"]
  f.confirm "deploy", "Auto-deploy to staging?", default: true
end

if config = result
  puts "Created project #{config["name"]} using #{config["db"]}!"
end
```

### 2. Live Fuzzy Filter with Split Preview

```crystal
require "opal"

branches = ["main", "staging", "feat/auth", "feat/fuzzy-finder", "fix/timeout"]

selected = Opal.filter(
  items: branches,
  title: "Git Switcher",
  preview: ->(b : String) { "Branch #{b}\nStatus: Clean\nUpdated: 5m ago" }
)

puts "Switched to branch: #{selected}" if selected
```

---

## 📝 Multi-Field Form & Wizard DSL

Traditional CLI prompts ask one question at a time and prevent reviewing earlier inputs. `Opal.form` presents an interactive card where all fields are visible simultaneously, users navigate using `Tab` / `Shift+Tab`, and live validation catches mistakes instantly.

```crystal
result = Opal.form("New Microservice") do |f|
  f.text "service", "Service Name:", required: true
  f.text "port", "HTTP Port:", default: "8080"
  f.password "secret", "Secret Key:", min_length: 6
  f.select "tier", "Hosting Tier:", ["Small", "Medium", "Large"]
  f.multi_select "plugins", "Plugins:", ["Metrics", "Tracing", "Auth"]
  f.confirm "enabled", "Enable service immediately?", default: true

  # Custom real-time validation
  f.validate "port" do |val|
    (val.to_i? && (1024..65535).includes?(val.to_i)) ? nil : "Port must be 1024-65535"
  end
end
```

---

## 🔍 Live Fuzzy Search & Filter

Fast, keystroke-responsive fuzzy filtering inspired by `fzf`:

- Instant substring matching with word boundary bonuses.
- Highlights matched characters in bold cyan.
- Split preview pane for viewing item details.

```crystal
choice = Opal.filter(
  items: Dir["src/**/*.cr"],
  title: "Fuzzy File Finder",
  preview: ->(path : String) { File.read(path).lines.first(15).join("\n") }
)
```

---

## 📊 Data Visualizations

Render rich dashboards and metrics without graphics libraries:

### Sparklines
```crystal
# Output:  ▂▄▇▇█▆▄▃▂▂
puts Opal::UI::Sparkline.render_to_string([10.0, 15.0, 25.0, 80.0, 95.0, 60.0])
```

### BarCharts, Gauges & Trees in UI Trees
```crystal
Opal.render_ui(width: 70, height: 20) do |ui|
  ui.vstack(spacing: 1) do |v|
    # Percentage Gauge
    v.gauge 0.76, label: "Disk Usage", color: :yellow

    # Horizontal Bar Chart
    v.barchart(title: "Memory Allocation") do |bc|
      bc.bar "Web", 420, color: :green
      bc.bar "Worker", 850, color: :cyan
      bc.bar "DB", 1200, color: :red
    end

    # Hierarchical Tree
    v.tree(title: "Service Graph") do |t|
      t.node("API Gateway", icon: "🌐") do |gateway|
        gateway.add("Auth Service", icon: "🔒")
        gateway.add("Search Node", icon: "🔍")
      end
    end
  end
end
```

---

## 🪟 Buffer Blitting, Modals & Toasts

### Floating Modal Dialog
Center a dialog box over any screen buffer with automatic background dimming:

```crystal
modal = Opal::UI::Modal.new(
  title: "Confirm Deletion",
  message: "Are you sure you want to drop database 'prod'?",
  buttons: ["Cancel", "Confirm Drop"],
  selected_button: 1
)
modal.render(buffer, 0, 0, 80, 24)
```

### Toast Notifications
Stack floating alerts in the top-right corner with auto-dismiss timers:

```crystal
toasts = Opal::UI::ToastManager.new
toasts.add("Build Succeeded", "All 124 tests passed", level: :success, duration_ms: 3000)
toasts.add("Disk Warning", "Free space below 10%", level: :warning)

toasts.render_overlay(buffer, position: :top_right)
```

---

## 📖 Terminal Markdown Viewer

Convert Markdown documents into styled ANSI terminal text:

```crystal
doc = <<-MD
# Opal Framework v1.0
Welcome to **Opal**! Build *beautiful* CLIs in Crystal.

### Features
- Zero external C dependencies
- 60fps delta rendering

```crystal
require "opal"
puts "Hello world!"
```

> "Simplicity is prerequisite for reliability."
MD

puts Opal.render_markdown(doc, width: 80)
```

---

## 🎨 Theme Engine & Semantic Colors

Opal includes pre-registered designer palettes and semantic color tokens:

```crystal
# Switch theme dynamically
Opal.theme = :catppuccin_mocha # :dracula, :nord, :tokyo_night, :gruvbox, etc.

# Semantic color tokens
theme = Opal.theme
style = Opal.style
  .foreground(theme.primary)
  .background(theme.surface)
  .border_foreground(theme.border)
```

---

## 🔍 Command Palette Overlay

Press `Ctrl+P` or `Ctrl+K` to summon an instant Spotlight action launcher:

```crystal
palette = Opal::UI::CommandPalette.new
palette.add("git:commit", "Commit changes", category: "Git", shortcut: "ctrl+c") { commit_flow }
palette.add("file:open", "Open file picker", category: "File", shortcut: "ctrl+o") { open_picker }
```

---

## 🔗 OSC 8 Hyperlinks & OSC 52 Clipboard

```crystal
# Clickable hyperlink in modern terminals
puts Opal.hyperlink("View Source on GitHub", "https://github.com/sol-vin/opal")

# Copy directly to OS desktop clipboard over SSH and local sessions
Opal.copy_to_clipboard("API_KEY_SECRET_12345")
```

---

## ⏱️ Animation & Easing Engine

Smooth transitions, progress bars, and color interpolation:

```crystal
# Easing functions
t = Opal::Animation.ease(:ease_in_out_cubic, 0.5)

# Color interpolation (e.g. green to red as CPU load increases)
normal_color = Opal::Color.green
alert_color  = Opal::Color.red
current_c    = Opal::Color.lerp(normal_color, alert_color, 0.75)
```

---

## 🛠️ CLI Application DSL

```crystal
app = Opal.cli("deployer", "Cloud deployment manager", "0.4.0") do
  option "-v", "--verbose", "Enable debug logging", type: :bool

  command "deploy", "Deploy application containers" do
    argument "service", "Service name to deploy"
    option "-c", "--concurrency=NUM", "Max concurrency", type: :int, default: 3

    run do |ctx|
      svc = ctx.argument("service")
      puts "Deploying #{svc} (concurrency: #{ctx.int("concurrency")})..."
    end
  end
end

app.run(ARGV)
```

---

## 🍵 The Elm Architecture (TEA)

Build reactive terminal applications with pure state transitions:

```crystal
record CounterModel, count : Int32 = 0 do
  include Opal::Tea::Model

  def init : Opal::Tea::Cmd
    Opal::Tea::Cmd.none
  end

  def update(msg : Opal::Tea::Msg) : {Opal::Tea::Model, Opal::Tea::Cmd}
    case msg
    when Opal::Tea::KeyMsg
      case msg.key
      when "up", "k"   then {CounterModel.new(count + 1), Opal::Tea::Cmd.none}
      when "down", "j" then {CounterModel.new(count - 1), Opal::Tea::Cmd.none}
      when "q"         then {self, Opal::Tea::Cmd.quit}
      else {self, Opal::Tea::Cmd.none}
      end
    else
      {self, Opal::Tea::Cmd.none}
    end
  end

  def view : String
    "Counter: #{count} (Press ↑/k, ↓/j, q to quit)"
  end
end

Opal::Tea::Program.new(CounterModel.new).run
```

---

## 🧪 Testing with MockDriver

Test full TUI interactions headlessly without opening an actual terminal:

```crystal
require "spec"
require "opal"

describe "Counter" do
  it "increments on keypress" do
    model = CounterModel.new
    new_model, cmd = model.update(Opal::Tea::KeyMsg.new("k"))
    new_model.as(CounterModel).count.should eq(1)
  end
end
```

---

## 📂 Examples

Explore all runnable examples in the [`examples/`](examples/) directory:

- [`01_lapis_revamp.cr`](examples/01_lapis_revamp.cr) — Comprehensive CLI developer toolchain with subcommands, typed options, and table reports.
- [`02_interactive_prompts.cr`](examples/02_interactive_prompts.cr) — Setup wizard showing `ask`, `confirm`, `select`, `multi_select`, `spinner`, and `progress`.
- [`03_tea_counter.cr`](examples/03_tea_counter.cr) — Classic Elm Architecture counter application with keyboard controls.
- [`04_system_dashboard.cr`](examples/04_system_dashboard.cr) — Live full-screen system monitor dashboard with charts, tables, and async metrics updates.
- [`05_autocomplete_and_input.cr`](examples/05_autocomplete_and_input.cr) — Interactive REPL showcasing Tab autocompletion, inline ghost-text hints, keymaps, mouse routing, and terminal inspection.
- [`06_rich_form_wizard.cr`](examples/06_rich_form_wizard.cr) — Multi-field form wizard with live validation, password masking, select menus, and checkboxes.
- [`07_fuzzy_finder.cr`](examples/07_fuzzy_finder.cr) — Live fuzzy search list with rune highlighting and split preview pane.
- [`08_dataviz_dashboard.cr`](examples/08_dataviz_dashboard.cr) — Rich analytics dashboard with Sparklines, BarCharts, Gauges, Trees, and Themes.
- [`09_markdown_and_overlays.cr`](examples/09_markdown_and_overlays.cr) — Terminal Markdown viewer, Modal dialogs, and floating Toast notifications.

Run any example:

```bash
crystal run examples/06_rich_form_wizard.cr
crystal run examples/08_dataviz_dashboard.cr
crystal run examples/09_markdown_and_overlays.cr
```

---

## 🌐 Cross-Platform Support

| Platform | Terminal Backend | Colors | Mouse Support |
| :--- | :--- | :--- | :--- |
| **Linux** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **macOS** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **Windows** | Win32 Console API (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) + ANSI VT100 | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
