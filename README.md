<div align="center">

# 💎 Opal

**Next-Generation Terminal User Interface (TUI) & CLI DSL Framework for Crystal**

[![CI](https://github.com/sol-vin/opal/actions/workflows/ci.yml/badge.svg)](https://github.com/sol-vin/opal/actions/workflows/ci.yml)
[![Crystal](https://img.shields.io/badge/crystal-%3E%3D%201.8.0-black.svg)](https://crystal-lang.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*Pure Crystal. Zero external C library dependencies (no ncurses). Native Windows, Linux, and macOS support.*

</div>

---

## 🌟 What is Opal?

**Opal** is an all-in-one terminal framework for [Crystal](https://crystal-lang.org) designed to build world-class command-line interfaces, micro-interactive prompts, and full-screen terminal applications.

It merges the best paradigms from modern terminal engineering into a cohesive, idiomatic Crystal DSL:
- 🍵 **The Elm Architecture (TEA)** — Pure, predictable state management inspired by [Bubble Tea](https://github.com/charmbracelet/bubbletea).
- 🎨 **Declarative Fluent Styling** — Lipgloss-inspired composable styling, borders, 24-bit TrueColor, visual string width, and box layouts.
- ⚡ **Flicker-Free Delta Rendering** — Blessed-inspired double buffering that computes minimal character delta updates for 60fps full-screen performance.
- 🛠️ **Expressive CLI App DSL** — Clap/Commander-style subcommands, typed flags, choices, global flag propagation, and shell completion (`bash`, `zsh`, `fish`).
- 🔮 **Ghost-Text Autocomplete & Input DSL** — Modern fish/zsh-style inline ghost text autocomplete on `Tab`, flexible interactive line editing, and declarative key bindings.
- 🖱️ **Hit-Test Mouse Routing DSL** — SGR extended mouse tracking with declarative click, drag, and scroll zones.
- 🖥️ **Terminal Capabilities DSL** — Automatic detection of TrueColor, 256 colors, Unicode width, and live terminal dimensions.

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
- [CLI Application DSL](#-cli-application-dsl)
  - [Defining Commands & Options](#defining-commands--options)
  - [Shell Completions](#shell-completions)
- [Fluent Styling & Layout](#-fluent-styling--layout)
  - [Colors & Modifiers](#colors--modifiers)
  - [Borders, Padding & Alignment](#borders-padding--alignment)
  - [Layout Combinators](#layout-combinators)
- [Interactive Prompts](#-interactive-prompts)
- [Autocomplete & Ghost Text DSL](#-autocomplete--ghost-text-dsl)
- [KeyMap & MouseMap DSLs](#-keymap--mousemap-dsls)
- [Terminal Info & Capabilities DSL](#-terminal-info--capabilities-dsl)
- [The Elm Architecture (TEA)](#-the-elm-architecture-tea)
- [Declarative UI & Diff Rendering](#-declarative-ui--diff-rendering)
- [Testing with MockDriver](#-testing-with-mockdriver)
- [Examples](#-examples)
- [License](#-license)

---

## 🚀 Quick Start

### 1. Build an Expressive CLI in 20 lines

```crystal
require "opal"

cli = Opal.cli("lapis", "Modern full-stack Crystal toolchain", "1.0.0") do
  command "build", "Compile production application" do
    argument "entry", "Application entry file", default: "src/main.cr"
    option "-r", "--release", "Compile with release optimizations", type: :bool
    option "-t", "--target=TRIPLE", "Cross-compilation target"

    run do |ctx|
      entry = ctx.argument("entry")
      release = ctx.bool?("release") ? " (release mode)" : ""
      puts "Building #{entry}#{release}..."
    end
  end
end

cli.run(ARGV)
```

### 2. Full-Screen Bubbletea-Style Counter

```crystal
require "opal"

record CounterModel, count : Int32 = 0 do
  include Opal::Tea::Model

  def init : Opal::Tea::Cmd
    Opal::Tea::Cmd.none
  end

  def update(msg : Opal::Tea::Msg) : {Opal::Tea::Model, Opal::Tea::Cmd}
    case msg
    when Opal::Tea::KeyMsg
      case msg.key
      when "up", "+", "k"   then {CounterModel.new(count + 1), Opal::Tea::Cmd.none}
      when "down", "-", "j" then {CounterModel.new(count - 1), Opal::Tea::Cmd.none}
      when "q", "ctrl+c"    then {self, Opal::Tea::Cmd.quit}
      else {self, Opal::Tea::Cmd.none}
      end
    else
      {self, Opal::Tea::Cmd.none}
    end
  end

  def view : String
    box = Opal.style
      .border(:rounded)
      .border_foreground(Opal::Style::Color.hex("#6C5CE7"))
      .padding(1, 4)
      .render(
        "Current count: #{Opal.style.bold.foreground(Opal::Style::Color.hex("#00CEC9")).render(count.to_s)}\n" \
        "Press [↑/k] Increment  [↓/j] Decrement  [q] Quit"
      )
    "\n" + box + "\n"
  end
end

Opal::Tea::Program.new(CounterModel.new).run
```

---

## 🏛️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                           Opal DSL                               │
│  Opal.cli  │  Opal.prompt  │  Opal.on_key  │  Opal.autocomplete  │
└──────┬─────────────┬──────────────┬──────────────────┬───────────┘
       │             │              │                  │
┌──────▼──────┐┌─────▼───────┐┌─────▼───────┐┌─────────▼───────────┐
│  CLI Engine ││ Interactive ││ TEA Runtime ││ Declarative UI DSL  │
│  Parser,    ││ Prompts &   ││ Model, Msg, ││ Box, VStack, HStack │
│  Completion ││ Micro-UI    ││ Cmd, Loops  ││ Table, Viewport     │
└──────┬──────┘└─────┬───────┘└─────┬───────┘└─────────┬───────────┘
       │             │              │                  │
┌──────▼─────────────▼──────────────▼──────────────────▼───────────┐
│                   Diff Renderer & Double Buffer                  │
│             Zero-flicker cell-level minimal delta screen         │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
┌──────────────────────────────────▼───────────────────────────────┐
│               Styling & Unicode Visual Engine                    │
│   24-bit TrueColor, ANSI 16/256, East Asian Width, Emoji visual  │
└──────────────────────────────────┬───────────────────────────────┘
                                   │
┌──────────────────────────────────▼───────────────────────────────┐
│               Terminal Driver (Zero C Dependencies)              │
│       POSIX (termios, ioctl)  │  Windows (Win32 Console & VT)    │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ CLI Application DSL

### Defining Commands & Options

Opal provides a declarative DSL for commands, subcommands, arguments, typed options, validation, and auto-generated help.

```crystal
app = Opal.cli("deployer", "Cloud deployment manager", "0.4.0") do
  # Global options inherit to all subcommands
  option "-v", "--verbose", "Enable debug logging", type: :bool
  option "--env=NAME", "Target environment", default: "staging", choices: ["dev", "staging", "prod"]

  command "deploy", "Deploy application containers" do
    argument "service", "Service name to deploy"
    option "-c", "--concurrency=NUM", "Max concurrent deployments", type: :int, default: 3
    option "-f", "--force", "Skip safety confirmation", type: :bool

    run do |ctx|
      svc = ctx.argument("service")
      env = ctx.string("env")
      concurrency = ctx.int("concurrency")
      verbose = ctx.bool?("verbose")

      puts "Deploying #{svc} to #{env} (concurrency: #{concurrency}, verbose: #{verbose})"
    end
  end
end

app.run(ARGV)
```

#### Features:
- **Type Casting**: `:string`, `:int`, `:float`, `:bool`, `:array`.
- **Validation**: Enforce valid inputs using `choices: [...]`.
- **Environment Fallbacks**: `env: "DEPLOY_ENV"` automatically pulls from environment variables.
- **Subcommands**: Nest commands arbitrarily deep (`service create instance`).
- **Help Output**: Beautiful ANSI-styled help screens generated automatically (`--help` or `-h`).

### Shell Completions

Generate native shell completions with zero extra gems:

```crystal
app.completion_script(:bash) # Generate Bash completion
app.completion_script(:zsh)  # Generate Zsh completion
app.completion_script(:fish) # Generate Fish completion
```

---

## 🎨 Fluent Styling & Layout

Inspired by Charm's [Lipgloss](https://github.com/charmbracelet/lipgloss), Opal's styling engine allows chaining modifiers on immutable style objects.

### Colors & Modifiers

```crystal
include Opal::Style

# Color formats: Hex, RGB, 256-color palette, or ANSI 16
primary = Color.hex("#6C5CE7")
accent  = Color.rgb(0, 206, 201)
warning = Color.palette_256(214)
dimmed  = Color.ansi_16(8)

style = Opal.style
  .bold
  .italic
  .underline
  .foreground(primary)
  .background(Color.hex("#2D3436"))

puts style.render("Styled text with Opal!")
```

### Borders, Padding & Alignment

```crystal
card = Opal.style
  .border(:rounded) # :single, :double, :rounded, :thick, :ascii, or :none
  .border_foreground(Color.hex("#0984E3"))
  .padding(1, 2)    # top/bottom: 1, left/right: 2
  .margin(0, 1)
  .width(40)
  .align(:center)

puts card.render("Hello, World!")
```

### Layout Combinators

Combine rendered blocks horizontally or vertically with automatic height and visual width alignment:

```crystal
left_pane = Opal.style.border(:rounded).width(25).render("Sidebar Menu\n- Dashboard\n- Settings")
right_pane = Opal.style.border(:rounded).width(50).render("Main Content\nWelcome to Opal!")

# Join horizontally with top alignment
dashboard = Opal::Style.join_horizontal(:top, [left_pane, right_pane])
puts dashboard
```

---

## 💬 Interactive Prompts

Opal includes lightweight, interactive prompts with full keyboard navigation:

### Ask, Confirm, Select & Multi-Select

```crystal
prompt = Opal.prompt

# Text input
username = prompt.ask("Enter your username:", default: "admin")

# Yes / No confirmation
proceed = prompt.confirm("Deploy to production?", default: false)

# Single choice list
role = prompt.select("Select target environment:", ["Development", "Staging", "Production"])

# Multi-select checklist
features = prompt.multi_select("Select features to enable:", ["Auth", "Metrics", "GraphQL", "Caching"])
```

### Async Spinners & Progress Bars

```crystal
# Animated spinner for background fibers
prompt.spinner("Downloading dependencies...") do
  sleep 2.seconds
end

# Smooth Unicode progress bar
progress = prompt.progress(total: 100, width: 30)
100.times do
  sleep 20.milliseconds
  progress.increment
end
```

---

## 🔮 Autocomplete & Ghost Text DSL

Opal features a fast, inline ghost-text autocomplete engine. As the user types, suggestions appear inline in dimmed text and can be accepted with `Tab`.

```crystal
engine = Opal.autocomplete(["status", "start", "stop", "restart", "deploy", "destroy"])

# Query candidates
engine.candidates("st") # => ["status", "start", "stop"]

# Ghost text suffix for inline rendering
engine.suffix("st") # => "atus" (completes "status")

# Tab completion cycle
engine.next_completion("st") # => "status"
engine.next_completion("st") # => "start"
```

### Interactive TextInput Component

Use the full-featured `Opal::Input::TextInput` line editor with built-in ghost text:

```crystal
input = Opal::Input::TextInput.new(
  prompt_prefix: "opal> ",
  completions: ["checkout", "commit", "push", "pull", "status", "rebase"]
)

# Renders prompt, user input, cursor, and dimmed ghost text preview!
print input.render
```

---

## ⌨️ KeyMap & MouseMap DSLs

### Key Binding DSL (`Opal.on_key`)

Handle keyboard shortcuts declaratively with automatic modifier parsing:

```crystal
keymap = Opal.on_key do
  bind "ctrl+s", "Save current file" do
    save_file
  end

  bind ["q", "ctrl+c"], "Quit application" do
    exit
  end

  bind "tab", "Accept completion" do
    autocomplete.accept
  end

  catch_all do |key|
    handle_character(key)
  end
end

# Feed parsed Opal::Terminal::Key events
keymap.handle(event)
```

### Mouse Routing DSL (`Opal.on_mouse`)

Map mouse click, double-click, scroll, and drag events to UI zones:

```crystal
mouse_map = Opal.on_mouse do
  zone :sidebar, x: 0, y: 0, width: 20, height: 25 do
    on :click do |event|
      puts "Sidebar clicked at (#{event.x}, #{event.y})"
    end

    on :scroll_up do
      scroll_sidebar(-1)
    end
  end

  zone :main_button, x: 25, y: 5, width: 12, height: 3 do
    on :click do
      submit_form
    end
  end
end

# Feed SGR mouse events
mouse_map.handle(mouse_event)
```

---

## 🖥️ Terminal Info & Capabilities DSL

Inspect terminal capabilities and dimensions effortlessly:

```crystal
term = Opal.terminal

puts "Interactive TTY : #{term.interactive?}"
puts "Color Support   : #{term.color_support}" # :truecolor, :palette_256, :ansi_16, or :none
puts "Unicode Support : #{term.unicode?}"
puts "TrueColor?      : #{term.truecolor?}"
puts "Screen Size     : #{term.width} columns x #{term.height} rows"
```

---

## 🍵 The Elm Architecture (TEA)

Build complex interactive terminal applications using pure state machines.

### 1. Model
Define your application state:

```crystal
record EditorModel, text : String = "", saved : Bool = false do
  include Opal::Tea::Model

  def init : Opal::Tea::Cmd
    Opal::Tea::Cmd.none
  end
```

### 2. Update
Handle messages and return a new model + commands:

```crystal
  def update(msg : Opal::Tea::Msg) : {Opal::Tea::Model, Opal::Tea::Cmd}
    case msg
    when Opal::Tea::KeyMsg
      if msg.matches?("ctrl+s")
        {EditorModel.new(text, saved: true), Opal::Tea::Cmd.none}
      elsif msg.matches?("ctrl+q")
        {self, Opal::Tea::Cmd.quit}
      else
        {self, Opal::Tea::Cmd.none}
      end
    when Opal::Tea::WindowSizeMsg
      # React to terminal resize events
      {self, Opal::Tea::Cmd.none}
    else
      {self, Opal::Tea::Cmd.none}
    end
  end
```

### 3. View
Render the UI string:

```crystal
  def view : String
    status = saved ? "SAVED" : "MODIFIED"
    "File Editor [#{status}]\n#{text}"
  end
end
```

### 4. Run the Program
```crystal
program = Opal::Tea::Program.new(EditorModel.new)
program.run
```

---

## ⚡ Declarative UI & Diff Rendering

Opal includes a declarative UI tree and a minimal double-buffered differential delta renderer. It only updates screen cells that actually changed, completely eliminating terminal flicker.

```crystal
ui = Opal.render_ui(width: 80, height: 24) do
  box border: :rounded, border_color: Opal::Style::Color.hex("#6C5CE7"), padding: 1 do
    vstack do
      badge "OPAL DASHBOARD", bg: Opal::Style::Color.hex("#0984E3"), fg: Opal::Style::Color.hex("#FFFFFF")
      rule char: "─", color: Opal::Style::Color.ansi_16(8)
      
      hstack do
        box width: 25 do
          text "CPU: 18.4%\nRAM: 4.2 GB / 16 GB"
        end

        table headers: ["PID", "Process", "Status"],
              rows: [
                ["1024", "crystal-server", "RUNNING"],
                ["2048", "opal-worker",    "IDLE"]
              ]
      end
    end
  end
end

puts ui
```

### Built-in Components:
- `box`: Styled containers with borders, padding, and alignment.
- `vstack` & `hstack`: Declarative vertical and horizontal layout stacks.
- `text`: Styled text with visual width wrapping.
- `badge`: Pill/tag indicators.
- `rule`: Horizontal divider lines.
- `table`: Auto-sized tables with headers, borders, and rows.
- `viewport`: Scrollable viewing windows for large buffers.

---

## 🧪 Testing with MockDriver

Opal is engineered for testability. You can run and verify full TUI interactions headlessly without opening an actual terminal using `Opal::Terminal::MockDriver`:

```crystal
require "spec"
require "opal"

describe "MyTUI" do
  it "updates on keypress" do
    mock = Opal::Terminal::MockDriver.new(width: 80, height: 24)
    model = CounterModel.new

    # Simulate keypress
    new_model, cmd = model.update(Opal::Tea::KeyMsg.new("k"))
    new_model.as(CounterModel).count.should eq(1)

    # Render into mock buffer
    output = new_model.view
    output.should contain("Current count: 1")
  end
end
```

---

## 📂 Examples

Explore the full runnable examples in the [`examples/`](examples/) directory:

- [`01_lapis_revamp.cr`](examples/01_lapis_revamp.cr) — Comprehensive CLI developer toolchain with subcommands, typed options, and table outputs.
- [`02_interactive_prompts.cr`](examples/02_interactive_prompts.cr) — Interactive setup wizard with ask, select, multi-select, spinner, and progress bars.
- [`03_tea_counter.cr`](examples/03_tea_counter.cr) — Classic Elm Architecture counter application with keyboard controls.
- [`04_system_dashboard.cr`](examples/04_system_dashboard.cr) — Live full-screen system monitor dashboard with charts, tables, and async metrics updates.
- [`05_autocomplete_and_input.cr`](examples/05_autocomplete_and_input.cr) — Interactive REPL showcasing Tab autocompletion, ghost-text preview, keymaps, mouse routing, and terminal inspection.

Run any example:

```bash
crystal run examples/01_lapis_revamp.cr -- --help
crystal run examples/05_autocomplete_and_input.cr
```

---

## 🌐 Cross-Platform Support

| Platform | Terminal Backend | Colors | Mouse Support |
| :--- | :--- | :--- | :--- |
| **Linux** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **macOS** | POSIX `termios`, VT100, SGR | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |
| **Windows** | Win32 Console API (`ENABLE_VIRTUAL_TERMINAL_PROCESSING`) + ANSI VT100 | TrueColor, 256, ANSI 16 | Yes (SGR 1006) |

---

## 🤝 Contributing

1. Fork it (<https://github.com/sol-vin/opal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
