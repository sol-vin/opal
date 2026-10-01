<div align="center">

# [*] Opal

**Next-Generation Terminal User Interface (TUI) & CLI DSL Framework for Crystal**

[![CI](https://github.com/sol-vin/opal/actions/workflows/ci.yml/badge.svg)](https://github.com/sol-vin/opal/actions/workflows/ci.yml)
[![Docs](https://img.shields.io/badge/docs-GitHub%20Pages-blue.svg)](https://sol-vin.github.io/opal/)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.8.0-black.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*Pure Crystal. Zero external C library dependencies (no ncurses). Native Windows, Linux, and macOS support.*

<br/>

[![asciicast](https://asciinema.org/a/jCBChISE2qKxOMeG.svg)](https://asciinema.org/a/jCBChISE2qKxOMeG)

</div>

---

## >> What is Opal?

**Opal** is an all-in-one terminal framework for [Crystal](https://crystal-lang.org) designed to build world-class command-line interfaces, micro-interactive prompts, and full-screen terminal applications.

It merges the best paradigms from modern terminal engineering into a cohesive, idiomatic Crystal DSL:
- [TEA] **The Elm Architecture (TEA)** — Pure, predictable state management inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
- [UI] **Declarative Fluent Styling & Themes** — Lipgloss-inspired composable styling, borders, 24-bit TrueColor, visual string width, and curated themes (Catppuccin, Dracula, TokyoNight, Nord, Gruvbox).
- [FX] **Flicker-Free Delta Rendering** — Blessed-inspired double buffering that computes minimal character delta updates for 60fps full-screen performance.
- [CLI] **Expressive CLI App DSL** — Clap/Commander-style subcommands, typed flags, choices, global flag propagation, and shell completion (`bash`, `zsh`, `fish`).
- [DOC] **Multi-Field Form & Wizard DSL** — All fields visible simultaneously, tab navigation, live inline validation, and instant submission.
- [SEARCH] **Live Fuzzy Search & Filter** — Instant keystroke matching with rune highlighting and split preview pane (`Opal.filter`).
- [VIZ] **Rich Data Visualizations** — Unicode block Sparklines, horizontal/vertical BarCharts, percentage Gauges, and hierarchical Trees.
- [WIN] **Layer Blending, Modals & Toasts** — Buffer `blit`, backdrop dimming, centered confirmation dialogs, and non-blocking toast queues.
- [DOC] **Terminal Markdown Viewer** — Styled headers, blockquotes, lists, and syntax colorized code blocks.
- [AUTO] **Ghost-Text Autocomplete & Input DSL** — Modern fish/zsh-style inline ghost text autocomplete on `Tab`, flexible interactive line editing, and declarative key bindings.
- [MOUSE] **Hit-Test Mouse Routing DSL** — SGR extended mouse tracking with declarative click, drag, and scroll zones.
- [OSC] **OSC 8 Links & OSC 52 Clipboard** — Native clickable terminal hyperlinks and desktop clipboard copying across SSH and local sessions.

---

## [PKG] Installation

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

## [TOC] Table of Contents

- [Live Interactive Showcases](#-live-interactive-showcases)
- [Quick Start](#-quick-start)
- [Multi-Field Form & Wizard DSL](#-multi-field-form--wizard-dsl)
- [Live Fuzzy Search & Filter](#-live-fuzzy-search--filter)
- [Interactive File Dialog & Explorer](#-interactive-file-dialog--explorer)
- [TrueColor 24-Bit Color Picker](#-truecolor-24-bit-color-picker)
- [2D & 3D Spatial Color Picker](#-2d--3d-spatial-color-picker)
- [Text Shaders & Terminal FX](#-text-shaders--terminal-fx)
- [Data Visualizations](#-data-visualizations)
- [Buffer Blitting, Modals & Toasts](#-buffer-blitting-modals--toasts)
- [Terminal Markdown Viewer](#-terminal-markdown-viewer)
- [Theme Engine & Semantic Colors](#-theme-engine--semantic-colors)
- [Command Palette Overlay](#-command-palette-overlay)
- [OSC 8 Hyperlinks & OSC 52 Clipboard](#-osc-8-hyperlinks--osc-52-clipboard)
- [Animation & Easing Engine](#-animation--easing-engine)
- [CLI Application DSL](#-cli-application-dsl)
- [Fluent Styling & Layout](#-fluent-styling--layout)
- [Declarative UI & Dual-Mode DSL Blending](#-declarative-ui--dual-mode-dsl-blending)
- [Interactive Prompts](#-interactive-prompts)
- [Autocomplete & Ghost Text DSL](#-autocomplete--ghost-text-dsl)
- [Interactive Controls & Puppeting Engine](#-interactive-controls--puppeting-engine)
- [KeyMap & MouseMap DSLs](#-keymap--mousemap-dsls)
- [The Elm Architecture (TEA)](#-the-elm-architecture-tea)
- [Testing with MockDriver](#-testing-with-mockdriver)
- [Asciicast & Asciinema VCR Recording (`opal/asciicast`)](#-asciicast--asciinema-vcr-recording)
- [Examples](#-examples)
- [Cross-Platform Support](#-cross-platform-support)
- [License](#-license)

---

## [RUN] Quick Start

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

## [DEMO] Live Interactive Showcases

Real, live recordings captured directly from Opal running in terminal sessions (click any recording to open in asciinema):

| Feature Demo | Live Terminal Asciicast |
| :--- | :--- |
| **Grand 34-Slide TUI Showcase Tour**<br/>• Full interactive tour across all Opal features<br/>• Multi-field form wizard with live validation<br/>• Live fuzzy search & file dialog explorer<br/>• 2D/3D rotatable color cubes, spheres & wheels<br/>• Image to ASCII engine (Half-block & Nearest-char)<br/>• Text shaders (Matrix rain, CRT, Starfield, Ripple, Tunnel) with bouncing window<br/>• Circular PieCharts & Cartesian LineGraphs<br/>• Sparklines, tables, code/hex views, modals & TEA<br/>• Declarative UI & Dual-Mode DSL Blending<br/>• Asciinema VCR Tape Deck & Playback Engine | [![asciicast](https://asciinema.org/a/jCBChISE2qKxOMeG.svg)](https://asciinema.org/a/jCBChISE2qKxOMeG) |
| **Multi-Field Form Wizard**<br/>• Tab / Shift+Tab focus navigation<br/>• Masked secret/password inputs<br/>• Live inline validation feedback<br/>• Multi-select checkboxes | [![asciicast](https://asciinema.org/a/AtHfXx9TETU0iynO.svg)](https://asciinema.org/a/AtHfXx9TETU0iynO) |
| **Live Fuzzy Search & Split Preview**<br/>• Realtime sub-millisecond filtering<br/>• Word-boundary rune highlighting<br/>• Instant split details pane | [![asciicast](https://asciinema.org/a/CdgldnJvhRGBGEuE.svg)](https://asciinema.org/a/CdgldnJvhRGBGEuE) |
| **Cluster Analytics Dashboard**<br/>• Rolling Unicode Sparklines<br/>• Colorized percentage Gauges<br/>• Horizontal BarCharts & Trees<br/>• Catppuccin Mocha theme | [![asciicast](https://asciinema.org/a/J87u80gsmyKUwKx9.svg)](https://asciinema.org/a/J87u80gsmyKUwKx9) |
| **Ghost-Text Autocomplete & Line Editor**<br/>• Modern fish/zsh inline suggestions<br/>• Single-keystroke `Tab` expansion<br/>• Full interactive line editing | [![asciicast](https://asciinema.org/a/7awRfosHKkYInRIP.svg)](https://asciinema.org/a/7awRfosHKkYInRIP) |
| **CLI Toolchain & Auto Help**<br/>• Colored help generator<br/>• Animated ANSI spinner<br/>• In-place Unicode progress bar | [![asciicast](https://asciinema.org/a/hZWeL8pGlqZAp65r.svg)](https://asciinema.org/a/hZWeL8pGlqZAp65r) |

> [!TIP]
> All recordings are managed under installation IDs `2a10705a-74a3-4c4f-b46a-7fd92d0c3b93` and `93d19fef-0835-4ebf-b218-cda99edbe21b`. You can permanently link them to your asciinema account via [https://asciinema.org/connect/2a10705a-74a3-4c4f-b46a-7fd92d0c3b93](https://asciinema.org/connect/2a10705a-74a3-4c4f-b46a-7fd92d0c3b93).

---

## [DOC] Multi-Field Form & Wizard DSL

[![asciicast](https://asciinema.org/a/AtHfXx9TETU0iynO.svg)](https://asciinema.org/a/AtHfXx9TETU0iynO)

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

## [SEARCH] Live Fuzzy Search & Filter

[![asciicast](https://asciinema.org/a/CdgldnJvhRGBGEuE.svg)](https://asciinema.org/a/CdgldnJvhRGBGEuE)

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

## [DIR] Interactive File Dialog & Explorer

Browse file systems with folder/file icons, formatted human-readable file sizes, live directory search filtering, and split file preview:

```crystal
# Standalone interactive file picker
selected_file = Opal.file_dialog(initial_path: "./src", mode: :open_file)
puts "Chosen file: #{selected_file}" if selected_file

# Declaratively inside a layout tree
Opal.render_ui(width: 80, height: 20) do |ui|
  ui.file_dialog(initial_path: ".")
end
```

---

## [UI] TrueColor 24-Bit Color Picker

Interactive color palette studio with Red, Green, Blue channel sliders, live TrueColor preview swatches, hex `#RRGGBB` calculations, luminance, and designer preset swatches:

```crystal
# Standalone interactive color picker
picked_color = Opal.pick_color(Opal::Color.hex("#89B4FA"))
if c = picked_color
  puts "Selected color: #{c.to_hex} (RGB: #{c.to_rgb})"
end

# Declaratively in an element tree
Opal.render_ui(width: 60, height: 16) do |ui|
  ui.color_picker(initial_color: Opal::Color.cyan)
end
```

---

## [3D] 2D & 3D Spatial Color Picker

Choose colors in continuous 2D and 3D geometric spaces. Features real-time pitch/yaw rotation (`w/a/s/d`), virtual cursor raycasting (`↑/↓/←/→`), depth buffering (Z-buffer), and surface sampling across multiple projection shapes:

- **3D RGB Cube**: Full TrueColor volume with 6 colored faces and rotatable perspective camera.
- **3D RGB Sphere**: Latitude/longitude polar mapping rendered as an orthographic 3D globe.
- **2D Hue Circle Wheel**: Radial hue spectrum with saturation-based center blend.
- **2D RGB Square Spectrum**: Continuous 2D gradient field.

```crystal
# Launch standalone interactive 3D color picker
chosen = Opal.pick_color_3d(initial_color: Opal::Color.hex("#F38BA8"), shape: :cube_3d)
if c = chosen
  puts "Selected color: #{c.to_hex} (R: #{c.r}, G: #{c.g}, B: #{c.b})"
end

# Declaratively in a UI tree
Opal.render_ui(width: 80, height: 24) do |ui|
  ui.color_picker_3d(shape: :sphere_3d, scale: 7.0)
end
```

---

## [FX] Text Shaders & Terminal FX

Manipulate the character buffer like a GPU fragment shader. Opal brings pixel-shader thinking to text terminals with normalized UV coordinates `(u, v) ∈ [0, 1]`, double-buffered ping-pong rendering, composable multi-pass pipelines, and sub-region scoping:

- **Mathematical Helpers**: `uv`, `time`, `dist_center`, `wave`, `noise`, and neighbor sampling (`sample`, `sample_left`, `sample_right`).
- **Sub-Region Scoping**: Apply shaders to full screen or restrict execution to any bounding `Rect(x, y, w, h)`.
- **Built-in Presets**: `matrix_rain`, `crt_terminal`, `glitch_pass`, `plasma_waves`, `fire_effect`, and `vignette`.

```crystal
# Compose a multi-pass post-processing pipeline
pipeline = Opal.shader_pipeline do |pipe|
  # Procedural plasma wave background
  pipe.plasma(speed: 2.5, scale: 6.0)

  # Custom fragment shader modifying character and colors
  pipe.fragment(label: "tint_and_dissolve") do |ctx|
    if ctx.noise(ctx.u * 10, ctx.v * 10) > 0.6
      ctx.fg = Opal::Color.hex("#89DCEB")
      ctx.char = '*'
    end
  end

  # Terminal retro scanlines and curvature vignette
  pipe.crt(scanline_opacity: 0.25, curvature: 0.15)
end

# Execute over an Opal Buffer
pipeline.render(buffer, time: 1.5)
```

---

## [VIZ] Data Visualizations

[![asciicast](https://asciinema.org/a/J87u80gsmyKUwKx9.svg)](https://asciinema.org/a/J87u80gsmyKUwKx9)

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
      t.node("API Gateway", icon: "[NET]") do |gateway|
        gateway.add("Auth Service", icon: "[SEC]")
        gateway.add("Search Node", icon: "[SEARCH]")
      end
    end
  end
end
```

---

## [WIN] Buffer Blitting, Modals & Toasts

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

## [DOC] Terminal Markdown Viewer

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

## [UI] Theme Engine & Semantic Colors

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

## [SEARCH] Command Palette Overlay

Press `Ctrl+P` or `Ctrl+K` to summon an instant Spotlight action launcher:

```crystal
palette = Opal::UI::CommandPalette.new
palette.add("git:commit", "Commit changes", category: "Git", shortcut: "ctrl+c") { commit_flow }
palette.add("file:open", "Open file picker", category: "File", shortcut: "ctrl+o") { open_picker }
```

---

## [OSC] OSC 8 Hyperlinks & OSC 52 Clipboard

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

## [CLI] CLI Application DSL

[![asciicast](https://asciinema.org/a/hZWeL8pGlqZAp65r.svg)](https://asciinema.org/a/hZWeL8pGlqZAp65r)

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

## [UI] Fluent Styling & Layout

Lipgloss-inspired declarative style chain with true visual string width calculation and 24-bit TrueColor:

```crystal
# Composable styling
header_style = Opal.style
  .bold
  .foreground(Opal::Color.cyan)
  .background(Opal::Color.from("#1e1e2e"))
  .padding(1, 2)
  .border(:rounded)

puts header_style.render("Welcome to Opal")

# Double-buffered layout rendering
rendered = Opal::UI.render(width: 80, height: 10) do |ui|
  ui.box(border: :rounded, title: "System Info") do |b|
    b.vstack do |v|
      v.text("CPU: 8 cores active")
      v.text("Memory: 16 GB DDR5")
    end
  end
end
puts rendered
```

---

## [UI] Declarative UI & Dual-Mode DSL Blending

> [!NOTE]
> For in-depth architectural details and component tables, see the [Architecture Guide: DSL & Blending](docs/architecture/dsl_and_blending.md).

Opal's UI DSL provides first-class support for **dual-mode block execution** (`with builder yield builder`) and **OOP-DSL blending**, allowing you to seamlessly mix declarative blocks with traditional component instances.

### 1. Concise Implicit Mode vs Explicit Receiver Mode

```crystal
# Concise Implicit Syntax: No block parameters required
dashboard = Opal.render_ui(width: 80, height: 12) do
  box(title: "Status Monitor", border: :rounded) do
    vstack(spacing: 1) do
      text "Cluster Node 01", fg: :cyan
      gauge ratio: 0.85, label: "CPU: 85%"
      hstack(spacing: 2) do
        badge "HEALTHY", :green
        badge "US-EAST-1", :blue
      end
    end
  end
end

# Explicit Receiver Syntax: Full typed parameter control
explicit = Opal.render_ui(width: 80, height: 12) do |ui|
  ui.box(title: "Status Monitor", border: :rounded) do |b|
    b.vstack(spacing: 1) do |v|
      v.text "Cluster Node 01", fg: :cyan
    end
  end
end
```

### 2. Blending Traditional OOP Instances into Declarative DSL

Any component created with `.new` can be directly embedded into DSL blocks using `add(el)`, `<< el`, or `custom(el)`:

```crystal
# 1. Create components traditionally
my_chart = Opal::UI::LineGraph.new
my_chart.add_series("Traffic", [10.0, 45.0, 30.0, 90.0], :cyan)

my_log = Opal::UI::RichLog.new
my_log.log("Worker connected")

# 2. Embed into declarative DSL tree
screen = Opal::UI.build do
  vstack(spacing: 1) do
    text "System Overview"
    add my_chart        # via add
    self << my_log      # via shovel << operator
  end
end
```

### 3. Container Constructors with DSL Blocks

Container classes (`Box`, `VStack`, `HStack`, `Screen`, `ModalScreen`) accept declarative DSL blocks directly:

```crystal
# Construct Box declaratively
box = Opal::UI::Box.new(title: "Block Box", border: :double) do
  text "Line 1"
  text "Line 2"
end

# Construct Screen with declarative root
screen = Opal::UI::Screen.new("main", title: "App Screen") do
  box(title: "Content") do
    text "Screen body"
  end
end
```

---

## [PROMPT] Interactive Prompts

```crystal
# Text, Confirm, Select, and Multi-Select
name = Opal.ask("Enter your username:", default: "developer")
confirmed = Opal.confirm("Continue with deployment?", default: true)
tier = Opal.select("Choose your deployment tier:", ["Small", "Medium", "Enterprise"])
features = Opal.multi_select("Select plugins:", ["Metrics", "Tracing", "RateLimiter"])

# Animated ANSI Spinner
Opal.spinner("Provisioning cluster resources...") do
  sleep 1.second
end

# In-Place Smooth Unicode Progress Bar
Opal.progress(total: 100, title: "Downloading Assets") do |bar|
  10.times do
    sleep 50.milliseconds
    bar.advance(10)
  end
end
```

---

## [AUTO] Autocomplete & Ghost Text DSL

[![asciicast](https://asciinema.org/a/7awRfosHKkYInRIP.svg)](https://asciinema.org/a/7awRfosHKkYInRIP)

Provide rich inline suggestions and command completion with zero terminal lag:

```crystal
# Static dictionary or dynamic query provider
engine = Opal::Input::Autocomplete.new(["checkout", "commit", "push", "pull", "status", "rebase"])

# Interactive line editor with ghost-text preview
input = Opal::Input::TextInput.new(placeholder: "Type a git command...")
input.autocomplete = engine

# Readline loop with inline preview
# Press [Tab] to accept ghost completion
# Press [Enter] to submit
```

---

## [CONTROL] Interactive Controls & Puppeting Engine

> [!NOTE]
> For in-depth architectural design, sequence diagrams, and lifecycle specifications, see the [Architecture Guide: Controls, Input Hooks & Engine](docs/architecture/input_hooks_and_engine.md).

Every interactive widget in Opal (`Table`, `FilterList`, `ColorPicker`, `ColorPicker3D`, `FileDialog`, and custom widgets) inherits from `Opal::UI::Control < Opal::UI::Element`. They implement standard input lifecycles, per-control input overrides, and code puppeting:

### 1. Default Inputs Lifecycle
Controls initialize standard keyboard and mouse bindings via `setup_default_inputs`:
```crystal
picker = Opal::UI::ColorPicker.new
# Standard arrow keys, tabs, numbers, and mouse scrubbing work out of the box!
```

### 2. Custom Input Hooks & Interceptors (`on_input`)
Intercept or augment input handling per control without subclassing:
```crystal
picker.on_input do |ctrl, event|
  if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "x"
    ctrl.color = Opal::Color.hex("#FF0000") # Custom shortcut: Instant red
    true # Consumed!
  else
    false # Fall back to default inputs (+, -, arrows, tabs)
  end
end
```

### 3. Programmatic Puppeting from Code (`puppet`)
Automate controls without physical user input (e.g. background ticker or playback script):
```crystal
table = Opal::UI::Table.new(headers: ["Job", "Status"])
table.puppet do |tbl, event|
  if event.is_a?(Opal::Terminal::KeyEvent) && event.name == "auto_tick"
    cur = tbl.selected_index || 0
    tbl.select((cur + 1) % tbl.rows.size)
    true
  else
    false
  end
end

# Drive the control programmatically:
table.handle_input(Opal::Terminal::KeyEvent.new("auto_tick"))
```

### 4. Multi-Control Focus Orchestration with `Opal::UI::Engine`
```crystal
engine = Opal::UI::Engine.new([table, picker])

# Tab / Shift+Tab cycles focus automatically:
engine.handle_key(Opal::Terminal::KeyEvent.new("tab"))

# Inject synthetic inputs for headless tests:
engine.send_key("down")
engine.send_mouse(15, 10, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)
```

For a complete runnable demonstration, check out [`examples/13_control_input_hooks_and_puppeting.cr`](examples/13_control_input_hooks_and_puppeting.cr).

---

## ⌨️ KeyMap & MouseMap DSLs

```crystal
# Declarative Keyboard Binding
key_map = Opal::Input::KeyMap.new
key_map.bind("ctrl+c", "Exit program") { exit }
key_map.bind("enter", "Confirm input") { save_data }
key_map.bind("up", "Navigate up") { cursor_up }

# Extended SGR Mouse Hit-Testing
mouse_map = Opal::Input::MouseMap.new
mouse_map.on_click(x_range: 2..15, y_range: 5..7) do
  puts "Deploy button clicked!"
end
mouse_map.on_scroll do |delta|
  scroll_view(delta)
end
```

---

## [TEA] The Elm Architecture (TEA)

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

## [TEST] Testing with MockDriver

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

## [DEMO] Asciicast & Asciinema VCR Recording (`opal/asciicast`)

> [!NOTE]
> For in-depth architectural design, format specifications, and parser details, see the [Architecture Guide: Asciicast System](docs/architecture/asciicast.md).

Generate pixel-perfect, flicker-free terminal recordings in the standard **Asciinema v2 (`.cast`)** format with zero external dependencies.

This feature is modular and packaged as an **optional require**:

```crystal
require "opal"
require "opal/asciicast"            # Screen recording, parsing, and driver
require "opal/asciicast/asciinema"  # VCR tape deck & playback engine
```

### 1. Tactile VCR Cassette Recording & Playback (`Opal::VCR`)

Control your recordings like a physical tape deck with `record`, `capture`, `pause`, `resume`, `stop`, `save`, and frame pacing:

```crystal
# Block recording with automatic pacing and save
Opal::VCR.record("session.cast", width: 80, height: 24, title: "VCR Demo") do |vcr|
  # Capture initial buffer frame
  vcr.capture(buffer1, advance: 0.1)

  # Pace multi-frame transitions
  vcr.wait_frames(count: 3, delay_per_frame: 0.05)

  # Temporarily pause recording for background setup
  vcr.pause
  # ... private setup ...
  vcr.resume

  vcr.capture(buffer2, advance: 0.1)
  vcr.hold(1.5) # Freeze final frame for 1.5s
end

# Inspect and step through recorded frames
vcr = Opal::VCR.new
vcr.load("session.cast")

puts "Frames: #{vcr.total_frames} | Duration: #{vcr.duration}s"

# Step frame-by-frame
frame = vcr.next_frame
prev  = vcr.prev_frame
seek  = vcr.seek(1.0) # seek to 1 second
start = vcr.rewind

# Composite frame into a canvas while respecting existing UI overlays
target = Opal::UI::Buffer.new(100, 30)
vcr.render_frame(target, x: 2, y: 1, respect_overlays: true)
```

### 2. Direct Screen Buffer Recording (`ScreenRecorder`)

Record raw double-buffered frames (`Opal::UI::Buffer`) directly from your UI components:

```crystal
recorder = Opal::Asciicast::ScreenRecorder.new("screen.cast", width: 80, height: 24)
recorder.start

# Render any UI element directly into buffer
buf = Opal::UI::Buffer.new(80, 24)
my_ui.render(buf, 0, 0, 80, 24)

# Capture exact frame without terminal flicker
recorder.capture_frame(buf, advance: 0.1)
recorder.hold(1.0)
recorder.stop.save
```

### 3. Headless Interactive Recording with `Opal::Asciicast::Driver`

Pass the headless driver into any Opal prompt, form wizard, or TEA program to record user interactions without an active terminal:

```crystal
driver = Opal::Asciicast.create_driver(width: 80, height: 24, title: "Form Wizard Demo")

# Inject simulated keystrokes
driver.inject_key("enter")

# Run prompt headlessly
Opal.form("Setup", driver: driver) do |f|
  f.confirm "deploy", "Deploy now?", default: true
end

driver.save("demos/form.cast")
```

### 4. Parsing & Assertions with `Opal::Asciicast.read`

```crystal
recording = Opal::Asciicast.read("session.cast")
puts "Duration: #{recording.duration}s | Outputs: #{recording.outputs.size}"
```

For a complete runnable demonstration, check out [`examples/14_asciicast_recording.cr`](examples/14_asciicast_recording.cr) and [`examples/18_dsl_blending_and_asciinema.cr`](examples/18_dsl_blending_and_asciinema.cr).

---

## [EXAMPLES] Examples

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
- [`10_opal_tui_showcase.cr`](examples/10_opal_tui_showcase.cr) — **Full-featured 23-slide linear TUI showcase tour** displaying every Opal feature with interactive mini-apps, file dialogs, 2D/3D color pickers, and live text shaders.
- [`11_text_shaders.cr`](examples/11_text_shaders.cr) — Realtime text shader playground demonstrating Matrix Rain, CRT scanlines, Glitch, Plasma waves, Fire FX, and multi-pass pipeline compositing.
- [`12_3d_color_picker.cr`](examples/12_3d_color_picker.cr) — Interactive 3D RGB Cube, 3D Sphere, 2D Wheel, and Spectrum color pickers with pitch/yaw rotation and surface raycasting.
- [`13_control_input_hooks_and_puppeting.cr`](examples/13_control_input_hooks_and_puppeting.cr) — Multi-control focus orchestration with `Opal::UI::Engine`, custom input hooks (`on_input`), Vim navigation, and automated background puppeting.
- [`14_asciicast_recording.cr`](examples/14_asciicast_recording.cr) — Standardized Asciinema v2 recording with `require "opal/asciicast"`, programmatic buffer capture, and headless driver execution.
- [`18_dsl_blending_and_asciinema.cr`](examples/18_dsl_blending_and_asciinema.cr) — Dual-mode declarative DSL blending (concise implicit vs explicit receiver, traditional OOP interoperability) and tactile VCR recording/playback with timeline stepping.

Run any example:

```bash
crystal run examples/10_opal_tui_showcase.cr
crystal run examples/11_text_shaders.cr
crystal run examples/12_3d_color_picker.cr
```

---

## [NET] Cross-Platform Support

| Platform | Terminal Backend | Colors | Mouse Support |
| :--- | :--- | :--- | :--- |
| **Linux** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **macOS** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **Windows** | Win32 Console API (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) + ANSI VT100 | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |

---

## [FILE] License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
