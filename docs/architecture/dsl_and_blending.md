# Opal DSL Architecture & Dual-Mode Blending

Opal provides a declarative Domain-Specific Language (DSL) for building complex Terminal User Interfaces (TUIs). Designed following modern DSL principles, Opal allows developers to seamlessly blend between high-level declarative builder syntax and traditional object-oriented component manipulation.

---

## Key Design Principles

1. **Dual-Mode Block Execution**: Every container block in Opal executes via `with builder yield builder`. Developers can write concise implicit blocks without block arguments, or explicit blocks with typed receivers.
2. **First-Class Interoperability**: Any component constructed traditionally with `.new` can be directly embedded into DSL blocks using `add(el)`, `<< el`, or `custom(el)`.
3. **Container Block Constructors**: All container components (`Box`, `VStack`, `HStack`, `Screen`, `ModalScreen`) support direct block-based declarative instantiation (`Box.new(...) { ... }`).
4. **Zero Code Duplication**: All 40+ component builder methods are unified in the `Opal::UI::DSL` module mixin, included by both `Builder` and `StackBuilder`.

---

## 1. Dual-Mode Block Execution

### Concise Implicit Mode
Opal's DSL changes the implicit method receiver within blocks to the current builder instance:

```crystal
require "opal"

rendered = Opal.render_ui(width: 80, height: 24) do
  box(title: "System Monitor", border: :rounded) do
    vstack(spacing: 1) do
      text "CPU Utilization", fg: :cyan
      gauge ratio: 0.72, label: "72%"
      hstack(spacing: 2) do
        badge "ONLINE", :green
        badge "PRODUCTION", :blue
      end
    end
  end
end
```

### Explicit Receiver Mode
For large applications or nested scopes where explicit naming improves clarity, developers can specify a block parameter:

```crystal
Opal.render_ui(width: 80, height: 24) do |ui|
  ui.box(title: "System Monitor", border: :rounded) do |b|
    b.vstack(spacing: 1) do |v|
      v.text "CPU Utilization", fg: :cyan
      v.gauge ratio: 0.72, label: "72%"
    end
  end
end
```

Both styles can even be mixed within the same tree.

---

## 2. Blending DSL and Traditional OOP

Opal allows existing component objects to be composed into DSL hierarchies without converting them to DSL calls.

### Embedding Pre-Built Instances with `add` / `<<` / `custom`

```crystal
# 1. Instantiate components traditionally
cpu_chart = Opal::UI::LineGraph.new
cpu_chart.add_series("Core 0", [12.0, 45.0, 68.0, 92.0], :cyan)

log_feed = Opal::UI::RichLog.new(max_lines: 500)
log_feed.log("Service worker started")

# 2. Embed directly into a declarative DSL tree
tree = Opal::UI.build do
  vstack(spacing: 1) do
    text "Dashboard Overview"
    add cpu_chart       # via add
    self << log_feed    # via shovel <<
  end
end
```

### Container Child Parameters

Components like `Box` accept a pre-built child directly in their constructor:

```crystal
my_table = Opal::UI::Table.new(["ID", "Status"])
my_table.row(["1", "Active"])

# Pass child to box helper
box_el = Opal::UI.build do
  box(title: "Active Tasks", child: my_table, border: :rounded)
end
```

---

## 3. Container Constructors with DSL Blocks

Container classes feature `.new` overloads that accept declarative blocks:

```crystal
# Box with declarative child block
box = Opal::UI::Box.new(title: "Diagnostics", border: :double) do
  vstack(spacing: 0) do
    text "Kernel: Linux 6.8.0"
    text "Uptime: 14 days"
  end
end

# VStack with child block
stack = Opal::UI::VStack.new(spacing: 1) do
  badge "CLUSTER HEALTH", :green
  text "All 12 nodes reporting"
end

# Screen with declarative root
main_screen = Opal::UI::Screen.new("dashboard", title: "Main Screen") do
  box(title: "Welcome") do
    text "Press Q to exit"
  end
end
```

---

## 4. Layout Containers: Dock & Grid

### Dock Layout

```crystal
dock = Opal::UI.dock do
  top { text "Header Bar", fg: :white }
  left { text "Sidebar Menu", fg: :gray }
  center { text "Main View Area" }
  bottom { text "Footer Status Bar", fg: :dark_gray }
end
```

### Grid Layout

```crystal
grid = Opal::UI.grid(
  columns: [GridTrack.fr(1.0), GridTrack.fr(2.0)],
  rows: [GridTrack.fixed(3), GridTrack.fr(1.0)],
  gutter_x: 2,
  gutter_y: 1
) do
  area(row: 0, col: 0) { text "Widget A" }
  area(row: 0, col: 1) { text "Widget B" }
  area(row: 1, col: 0, col_span: 2) { text "Full Width Footer" }
end
```

---

## 5. Summary of DSL Methods

The `Opal::UI::DSL` module exposes full builder support for:

| Category | Components |
|:---|:---|
| **Text & Badges** | `text`, `badge`, `rule`, `digits`, `placeholder`, `markdown` |
| **Containers & Stacks** | `box`, `vstack`, `hstack`, `window`, `collapsible`, `viewport` |
| **Data Displays** | `table`, `tree`, `hex_viewer`, `code_view`, `rich_log`, `loading_indicator` |
| **Charts & Graphs** | `sparkline`, `barchart`, `pie_chart`, `line_graph`, `gauge` |
| **Controls & Inputs** | `button`, `dropdown`, `scrollbar`, `switch`, `checkbox`, `slider`, `radio_set` |
| **Pickers & Dialogs** | `file_dialog`, `color_picker`, `color_picker_3d`, `modal` |
| **Graphics & 3D** | `canvas_2d`, `mesh_3d`, `ascii_image` |
| **App Framing** | `header`, `footer`, `tabs`, `split_view`, `content_switcher` |
| **Object Interop** | `add(el)`, `<< el`, `custom(el)` |
