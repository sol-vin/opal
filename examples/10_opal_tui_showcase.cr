require "../src/opal"

# =============================================================================
# [*] OPAL FULL-FEATURED TUI SHOWCASE & INTERACTIVE DEMO APP
# =============================================================================
# A complete, linear interactive presentation demonstrating all
# capabilities of the Opal framework.
#
# Navigation:
#   [Shift+→]         : Advance to Next Slide
#   [Shift+←]         : Return to Previous Slide
#   [ESC] or [Ctrl+C] : Exit Demo
#   (Interactive controls for each slide are displayed in the footer)
# =============================================================================

abstract class ShowcaseSlide
  abstract def title : String
  abstract def category : String
  abstract def hints : String

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    false
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    false
  end

  def tick : Nil
  end

  abstract def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
end

# -----------------------------------------------------------------------------
# Slide 1: Welcome & Overview (Markdown Viewer)
# -----------------------------------------------------------------------------
class WelcomeSlide < ShowcaseSlide
  getter viewer : Opal::UI::MarkdownViewer

  def initialize
    doc = <<-MD
    # [*] Welcome to Opal TUI Framework

    **Next-Generation Terminal User Interface & CLI DSL for Crystal**

    Opal unifies the best terminal engineering paradigms into a cohesive framework:
    - [TEA] **The Elm Architecture (TEA)** — Pure, predictable state transitions (Bubbletea style).
    - [UI]  **Declarative Fluent Styling & Themes** — Lipgloss-inspired styling, 24-bit TrueColor, visual width calculation.
    - [FX]  **Flicker-Free Delta Rendering** — Blessed-inspired double buffering for 60fps smooth updates.
    - [CTL] **Rich Interactive Components** — Multi-field forms, live fuzzy search, file dialogs, and color pickers.
    - [VIZ] **Terminal Data Visualizations** — Sparklines, bar charts, pie charts, line graphs, gauges, and trees.

    > *"Build world-class command-line interfaces with zero external C dependencies."*

    ### >> Presentation Navigation Controls
    - **Press `[Shift+→]`** to advance to the next slide.
    - **Press `[Shift+←]`** to navigate back to the previous slide.
    - **Press `[ESC]`** at any time to exit and return to your shell.
    - **Press `[PageUp] / [PageDown]`** or `[↑/↓]` to scroll this markdown viewer.
    MD

    @viewer = Opal::UI::MarkdownViewer.new(doc, width: 80)
  end

  def title : String
    "Welcome to Opal"
  end

  def category : String
    "Overview & Markdown"
  end

  def hints : String
    "[PageUp/Down] Scroll Markdown Document"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @viewer.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @viewer.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @viewer.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 2: Multi-Field Form Wizard (Interactive App)
# -----------------------------------------------------------------------------
class FormWizardSlide < ShowcaseSlide
  getter form : Opal::FormModule::Form
  getter? submitted : Bool = false

  def initialize
    @form = Opal::FormModule::Form.new("Production Deployment Wizard")
    @form.text("cluster", "Cluster Name:", default: "alpha-mesh-01", required: true)
    @form.password("token", "API Secret Token:", min_length: 6, default: "sec_993478a")
    @form.select("region", "Target Region:", ["us-east-1", "us-west-2", "eu-central-1", "ap-southeast-1"])
    @form.multi_select("addons", "Addons:", ["Redis Cache", "Kafka Mesh", "Prometheus", "OpenTelemetry"], selected: ["Redis Cache", "Prometheus"])
    @form.confirm("auto_deploy", "Auto-deploy to production on save?", default: true)

    @form.validate("cluster") do |val|
      val.size >= 4 ? nil : "Cluster name must be at least 4 characters"
    end
  end

  def title : String
    "Multi-Field Form Wizard"
  end

  def category : String
    "Interactive Form DSL"
  end

  def hints : String
    "[Tab/Shift+Tab] Move Field   [Space] Toggle/Select   [Enter] Validate"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "tab", "down"
      @form.focus_next
      true
    when "shift+tab", "up"
      @form.focus_prev
      true
    when "enter"
      @submitted = @form.valid?
      true
    else
      if active_f = @form.fields[@form.active_field_idx]?
        if active_f.handle_key(key)
          active_f.error = nil
          @submitted = false
          return true
        end
      end
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @form.focus_prev
      true
    when Opal::Terminal::MouseButton::WheelDown
      @form.focus_next
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        @submitted = @form.valid?
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    form_w = Math.min(w - 4, 66)
    form_h = Math.min(h - 2, 17)
    @form.render(buffer, x + 2, y + 1, form_w, form_h)

    # Show validation feedback badge
    stat_y = y + form_h + 1
    if stat_y < y + h
      if @submitted
        buffer.put_string(x + 4, stat_y, "[OK] Form Validated & Ready for Deployment!", fg: Opal::Color.green, bold: true)
      else
        buffer.put_string(x + 4, stat_y, "[i] Edit fields with Tab/Space. Press [Enter] to validate.", fg: Opal::Color.cyan)
      end
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 3: Multi-Field Form Architecture (Code & Explanatory)
# -----------------------------------------------------------------------------
class FormCodeSlide < ShowcaseSlide
  def title : String
    "Form DSL Architecture"
  end

  def category : String
    "Architecture & Code"
  end

  def hints : String
    "Pure Crystal DSL • Zero C Dependencies • Interactive Form"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Why Multi-Field Forms Matter", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Traditional CLI wizards ask one question at a time and prevent correcting prior fields.", fg: Opal::Color.white)
    buffer.put_string(x + 2, y + 3, "Opal presents an interactive card where all inputs are visible simultaneously with live validation.", fg: Opal::Color.white)

    code = <<-CR
    require "opal"

    config = Opal.form("Cluster Setup") do |f|
      f.text "cluster", "Cluster Name:", required: true
      f.password "token", "API Token:", min_length: 8
      f.select "region", "Region:", ["us-east", "eu-central"]
      f.multi_select "addons", "Addons:", ["Redis", "Kafka", "Metrics"]
      f.confirm "deploy", "Deploy now?", default: true

      f.validate "cluster" do |val|
        val =~ /^[a-z0-9-]+$/ ? nil : "Lowercase alphanumeric & dashes only"
      end
    end
    CR

    cv = Opal::UI::CodeView.new(code: code, language: :crystal, show_line_numbers: true)
    cv.render(buffer, x + 2, y + 5, w - 4, h - 7)
  end
end

# -----------------------------------------------------------------------------
# Slide 4: Live Fuzzy Search & Filter (Interactive App)
# -----------------------------------------------------------------------------
class FuzzyFinderSlide < ShowcaseSlide
  getter filter_list : Opal::UI::FilterList

  def initialize
    items = [
      "auth-service (OAuth2 / JWT Token Gateway)",
      "billing-worker (Stripe & Invoice Processor)",
      "cart-cache (Redis Cluster Shard A)",
      "catalog-index (Elasticsearch Product Catalog)",
      "delivery-router (Vehicle Route Optimization)",
      "email-notifier (SES / SendGrid Dispatcher)",
      "fraud-detector (ML Anomaly Inference Node)",
      "graphql-gateway (Federated Schema Endpoint)",
      "image-resizer (Fast WebP Image Transformer)",
      "inventory-sync (Warehouse Stock Coordinator)",
      "log-aggregator (Vector / ClickHouse Pipeline)",
      "metrics-collector (Prometheus Telemetry Scraper)",
      "payment-gateway (PCI-DSS Vault Connector)",
      "rate-limiter (Token Bucket Distributed Filter)",
      "user-preferences (DynamoDB Document Store)",
    ]

    preview = ->(item : String) {
      name = item.split(' ').first
      "Service Details: #{name}\n" \
      "───────────────────────────────────\n" \
      "Status     : Healthy (100% SLA)\n" \
      "Replicas   : 4 pods active\n" \
      "Latency    : 1.4ms (p99)\n" \
      "CPU Usage  : 24%\n" \
      "Memory     : 340 MB / 1024 MB\n\n" \
      "Press [Enter] to inspect telemetry."
    }

    @filter_list = Opal::UI::FilterList.new(items: items, title: "[?] Microservice Search (Fuzzy Filter)", preview_fn: preview)
  end

  def title : String
    "Live Fuzzy Search & Filter"
  end

  def category : String
    "Interactive Search"
  end

  def hints : String
    "[Type] Filter query   [↑/↓] Select   [Backspace] Delete"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "ctrl+p"
      @filter_list.cursor_up
      true
    when "down", "ctrl+n"
      @filter_list.cursor_down
      true
    when "backspace"
      @filter_list.backspace
      true
    else
      if key.name.size == 1 && !key.ctrl? && !key.alt?
        @filter_list.append_char(key.name[0])
        true
      else
        false
      end
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @filter_list.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 5: File Dialog & Explorer (Interactive App - NEW COMPONENT)
# -----------------------------------------------------------------------------
class FileDialogSlide < ShowcaseSlide
  getter dialog : Opal::UI::FileDialog

  def initialize
    @dialog = Opal::UI::FileDialog.new(".", mode: :open_file)
  end

  def title : String
    "File Dialog & Explorer"
  end

  def category : String
    "Core TUI Component (New)"
  end

  def hints : String
    "[↑/↓] Navigate   [Enter] Enter Folder / Select   [Backspace/←] Up   [Type] Filter"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @dialog.handle_key(key)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @dialog.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 6: File Dialog Architecture & API (Code & Explanatory)
# -----------------------------------------------------------------------------
class FileDialogCodeSlide < ShowcaseSlide
  def title : String
    "FileDialog Architecture"
  end

  def category : String
    "Architecture & Code"
  end

  def hints : String
    "Cross-Platform Directory Traversal • Tree & Split Preview"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Opal::UI::FileDialog & FilePicker DSL", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Cross-platform directory traversal with icons, formatted sizes, filter search, and split preview.", fg: Opal::Color.white)

    code = <<-CR
    require "opal"

    # Standalone interactive picker:
    selected = Opal.file_dialog(
      initial_path: "./src",
      mode: :open_file,
      show_hidden: false
    )
    puts "Selected file: \#{selected}" if selected

    # Or declaratively inside any element tree:
    Opal.render_ui(width: 80, height: 20) do |ui|
      ui.file_dialog("./spec")
    end
    CR

    cv = Opal::UI::CodeView.new(code: code, language: :crystal, show_line_numbers: true)
    cv.render(buffer, x + 2, y + 4, w - 4, h - 6)
  end
end

# -----------------------------------------------------------------------------
# Slide 7: Color Picker & Palette Studio (Interactive App - NEW COMPONENT)
# -----------------------------------------------------------------------------
class ColorPickerSlide < ShowcaseSlide
  getter picker : Opal::UI::ColorPicker

  def initialize
    @picker = Opal::UI::ColorPicker.new(Opal::Color.hex("#89B4FA"))
  end

  def title : String
    "Color Picker & TrueColor Studio"
  end

  def category : String
    "Core TUI Component (New)"
  end

  def hints : String
    "[Click/Drag] Sliders & Presets   [Tab] Channel   [←/→] Adjust   [1-9] Preset"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @picker.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @picker.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @picker.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 8: Color Picker & TrueColor Engine (Code & Explanatory)
# -----------------------------------------------------------------------------
class ColorPickerCodeSlide < ShowcaseSlide
  def title : String
    "TrueColor Engine & Palettes"
  end

  def category : String
    "Architecture & Code"
  end

  def hints : String
    "24-Bit TrueColor RGB • Linear Gradients • Palettes"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> 24-Bit TrueColor & Color Interpolation", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Full RGB (16.7M colors), automatic 256-color fallback, hex parsing/formatting, and lerp.", fg: Opal::Color.white)

    code = <<-CR
    require "opal"

    # Standalone interactive color picker prompt:
    color = Opal.pick_color(Opal::Color.hex("#CBA6F7"))
    puts "Picked color: \#{color.to_hex}" if color

    # Smooth color gradients with linear interpolation:
    c_start = Opal::Color.green
    c_alert = Opal::Color.red
    halfway = Opal::Color.lerp(c_start, c_alert, 0.5)

    # Declarative styling with 24-bit RGB:
    style = Opal.style.foreground(color).bold
    puts style.render("Styled in TrueColor!")
    CR

    cv = Opal::UI::CodeView.new(code: code, language: :crystal, show_line_numbers: true)
    cv.render(buffer, x + 2, y + 4, w - 4, h - 6)
  end
end

# -----------------------------------------------------------------------------
# Slide 9: Cluster Analytics Data Visualizations (Interactive App)
# -----------------------------------------------------------------------------
class DatavizSlide < ShowcaseSlide
  @cpu_data : Array(Float64) = [15.0, 22.0, 35.0, 60.0, 78.0, 92.0, 84.0, 65.0, 50.0, 42.0, 55.0, 68.0, 75.0, 80.0]
  @cycle : Int32 = 0

  def title : String
    "Cluster Analytics & DataViz"
  end

  def category : String
    "Data Visualizations"
  end

  def hints : String
    "[Live Ticking Telemetry] • Sparklines & Gauges"
  end

  def tick : Nil
    @cycle += 1
    # Add gentle fluctuation to sparkline
    new_val = (40.0 + (@cycle * 11) % 55).to_f
    @cpu_data.shift if @cpu_data.size >= 18
    @cpu_data << new_val
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1

    buffer.put_string(x + 2, cur_y, ">> Real-Time Cluster Telemetry Dashboard", fg: Opal::Color.cyan, bold: true)
    cur_y += 2

    # Top Sparklines & Gauges
    half_w = (w - 6) // 2

    # Left: CPU Sparkline & Gauge
    buffer.put_string(x + 2, cur_y, "CPU Activity Trend (Rolling):", fg: Opal::Color.white, bold: true)
    cur_y += 1
    spark = Opal::UI::Sparkline.new(@cpu_data, color: :cyan)
    spark.render(buffer, x + 2, cur_y, half_w, 1)
    cur_y += 1

    cpu_ratio = (@cpu_data.last? || 50.0) / 100.0
    gauge = Opal::UI::Gauge.new(cpu_ratio, label: "Current Load: #{(cpu_ratio * 100).to_i}%", color: cpu_ratio > 0.75 ? :red : :yellow)
    gauge.render(buffer, x + 2, cur_y, half_w, 1)
    cur_y += 2

    # BarChart
    buffer.put_string(x + 2, cur_y, "Service Memory Footprint (MB):", fg: Opal::Color.white, bold: true)
    cur_y += 1

    bc = Opal::UI::BarChart.new
    bc.add("Web Gateway", 420.0 + (@cycle * 3) % 80, Opal::Color.green)
    bc.add("Worker Pool", 850.0 + (@cycle * 7) % 120, Opal::Color.cyan)
    bc.add("Database Node", 1240.0, Opal::Color.magenta)
    bc.add("Redis Cache", 310.0, Opal::Color.yellow)
    bc.render(buffer, x + 2, cur_y, w - 4, 4)
    cur_y += 5

    # Hierarchical Tree
    buffer.put_string(x + 2, cur_y, "Distributed Service Graph:", fg: Opal::Color.white, bold: true)
    cur_y += 1
    tr = Opal::UI::Tree.new
    tr.add("Opal Ingress Controller", Opal::Color.cyan, ">>") do |ingress|
      ingress.add("Authentication Node", Opal::Color.green, "*")
      ingress.add("Search & Index Cluster", Opal::Color.yellow, "?") do |search|
        search.add("Shard Alpha (Active)", Opal::Color.bright_black, "+")
        search.add("Shard Beta (Replica)", Opal::Color.bright_black, "+")
      end
    end
    tr.render(buffer, x + 2, cur_y, w - 4, Math.max(3, (y + h - 1) - cur_y))
  end
end

# -----------------------------------------------------------------------------
# Slide 10: Pie & Donut Visualizations (Interactive App - NEW)
# -----------------------------------------------------------------------------
class PieChartSlide < ShowcaseSlide
  property? donut_mode : Bool = false
  @tick_count : Int32 = 0

  def title : String
    "Pie & Donut Charts"
  end

  def category : String
    "Data Visualizations (New)"
  end

  def hints : String
    "[Space] Toggle Donut / Pie Mode"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    if key.matches?("space") || key.name == "space" || key.name == " " || key.char == ' '
      @donut_mode = !@donut_mode
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        @donut_mode = !@donut_mode
        true
      else
        false
      end
    when Opal::Terminal::MouseButton::WheelUp, Opal::Terminal::MouseButton::WheelDown
      @donut_mode = !@donut_mode
      true
    else
      false
    end
  end

  def tick : Nil
    @tick_count += 1
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> TrueColor Circular & Donut Visualizations", fg: Opal::Color.cyan, bold: true)
    mode_text = @donut_mode ? "[Mode: Donut Chart]" : "[Mode: Standard Pie]"
    buffer.put_string(x + 48, cur_y, mode_text, fg: Opal::Color.bright_black, italic: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "─" * Math.min(w - 4, 66), fg: Opal::Color.bright_black)
    cur_y += 1

    chart = Opal::UI::PieChart.new(
      donut: @donut_mode,
      inner_radius_ratio: 0.44
    )
    api_val = 45.0 + Math.sin(@tick_count * 0.1) * 8.0
    db_val = 30.0 + Math.cos(@tick_count * 0.1) * 6.0
    cache_val = 15.0
    queue_val = 10.0

    chart.add("API Gateway", api_val, Opal::Color.hex("#89B4FA"), "#{api_val.round(1)} req/s")
    chart.add("Database Pool", db_val, Opal::Color.hex("#A6E3A1"), "#{db_val.round(1)} qps")
    chart.add("Redis Cache", cache_val, Opal::Color.hex("#FAB387"), "#{cache_val.round(1)} hits")
    chart.add("Message Queue", queue_val, Opal::Color.hex("#CBA6F7"), "#{queue_val.round(1)} msg")

    chart.render(buffer, x + 2, cur_y, w - 4, h - 3)
  end
end

# -----------------------------------------------------------------------------
# Slide 11: 2D Cartesian Line Graphs (Interactive App - NEW)
# -----------------------------------------------------------------------------
class LineGraphSlide < ShowcaseSlide
  @latency_data : Array(Float64) = [14.0, 18.0, 22.0, 35.0, 42.0, 38.0, 28.0, 24.0, 30.0, 45.0, 52.0, 48.0, 32.0, 26.0, 22.0]
  @throughput_data : Array(Float64) = [80.0, 85.0, 92.0, 95.0, 78.0, 65.0, 70.0, 88.0, 94.0, 90.0, 82.0, 75.0, 84.0, 89.0, 91.0]
  @tick_count : Int32 = 0

  def title : String
    "2D Cartesian Line Graphs"
  end

  def category : String
    "Data Visualizations (New)"
  end

  def hints : String
    "[Live Telemetry Stream] • Real-Time Dual-Series Plot"
  end

  def tick : Nil
    @tick_count += 1
    new_lat = (25.0 + Math.sin(@tick_count * 0.25) * 18.0 + (@tick_count % 7)).clamp(5.0, 70.0)
    new_thru = (80.0 + Math.cos(@tick_count * 0.2) * 15.0).clamp(40.0, 100.0)

    @latency_data.shift if @latency_data.size >= 32
    @latency_data << new_lat

    @throughput_data.shift if @throughput_data.size >= 32
    @throughput_data << new_thru
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> Multi-Series Cartesian Line Plots with Gridlines", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "─" * Math.min(w - 4, 66), fg: Opal::Color.bright_black)
    cur_y += 1

    graph = Opal::UI::LineGraph.new(
      min_y: 0.0,
      max_y: 100.0,
      show_grid: true,
      show_legend: true
    )
    graph.add_series("Latency p99 (ms)", @latency_data, Opal::Color.hex("#F38BA8"))
    graph.add_series("Throughput (k req/s)", @throughput_data, Opal::Color.hex("#89B4FA"))

    graph.render(buffer, x + 2, cur_y, w - 4, h - 3)
  end
end

# -----------------------------------------------------------------------------
# Slide 12: Formatted Data Tables & Viewport (Interactive App)
# -----------------------------------------------------------------------------
class TablesSlide < ShowcaseSlide
  getter table : Opal::UI::Table
  getter viewport : Opal::UI::Viewport
  property active_pane : Symbol = :table

  def initialize
    headers = ["Service", "Namespace", "Load", "Uptime", "Health"]
    rows = [
      ["auth-service", "security", "14%", "12d 4h", "ACTIVE"],
      ["api-gateway", "ingress", "48%", "45d 1h", "ACTIVE"],
      ["cache-tier-1", "storage", "82%", "9d 2h", "WARNING"],
      ["db-primary", "database", "65%", "120d", "ACTIVE"],
      ["worker-batch", "compute", "95%", "2d 8h", "OVERLOADED"],
      ["metrics-agent", "telemetry", "4%", "45d 1h", "ACTIVE"],
    ]

    @table = Opal::UI::Table.new(headers: headers, rows: rows, zebra: true, selected_index: 0)

    log_content = <<-LOG
    [2026-09-30 08:30:01] INFO  auth-service: Issued JWT token for user_id=4021
    [2026-09-30 08:30:02] DEBUG api-gateway: Ingress route /api/v2 matched upstream
    [2026-09-30 08:30:03] WARN  cache-tier-1: Eviction rate exceeded threshold (140/s)
    [2026-09-30 08:30:04] INFO  db-primary: Checkpoint complete, 42MB written in 12ms
    [2026-09-30 08:30:05] WARN  worker-batch: CPU throttling engaged on container
    [2026-09-30 08:30:06] INFO  metrics-agent: Flushed 14,200 samples to Prometheus
    [2026-09-30 08:30:07] DEBUG api-gateway: TLS handshake completed in 1.1ms
    LOG

    @viewport = Opal::UI::Viewport.new(content: log_content, show_scrollbar: true)
  end

  def title : String
    "Tables & Scrollable Viewports"
  end

  def category : String
    "Layout & Data"
  end

  def hints : String
    "[↑/↓] Select Row / Scroll   [Tab] Switch Table/Logs"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "tab"
      @active_pane = (@active_pane == :table ? :viewport : :table)
      true
    when "up", "k"
      if @active_pane == :table
        @table.move_up
      else
        @viewport.scroll_up
      end
      true
    when "down", "j"
      if @active_pane == :table
        @table.move_down
      else
        @viewport.scroll_down
      end
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      if @active_pane == :table
        @table.move_up
      else
        @viewport.scroll_up
      end
      true
    when Opal::Terminal::MouseButton::WheelDown
      if @active_pane == :table
        @table.move_down
      else
        @viewport.scroll_down
      end
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        @active_pane = (event.y >= 14 ? :viewport : :table)
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "[#] Fleet Service Table (#{(@active_pane == :table ? "FOCUS" : "")})", fg: Opal::Color.cyan, bold: true)
    @table.render(buffer, x + 2, y + 3, w - 4, 8)

    vp_y = y + 12
    if vp_y < y + h - 2
      buffer.put_string(x + 2, vp_y, "[#] Live Audit Stream (#{(@active_pane == :viewport ? "FOCUS" : "")})", fg: Opal::Color.cyan, bold: true)
      @viewport.render(buffer, x + 2, vp_y + 1, w - 4, Math.max(3, (y + h - 1) - (vp_y + 1)))
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 11: Developer Tools: Code View & Hex Viewer (Interactive App)
# -----------------------------------------------------------------------------
class DevToolsSlide < ShowcaseSlide
  getter code_view : Opal::UI::CodeView
  getter hex_viewer : Opal::UI::HexViewer

  def initialize
    sample_code = <<-CR
    def dispatch_event(event : Event) : Nil
      case event
      when PacketIn
        buffer = event.bytes
        parse_header(buffer)
      when Disconnect
        cleanup_socket(event.id)
      end
    end
    CR

    @code_view = Opal::UI::CodeView.new(code: sample_code, language: :crystal, highlighted_line: 4)

    raw_bytes = Bytes[
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x20, 0x00, 0x20, 0x00, 0xF7, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x7F, 0x45, 0x4C, 0x46, 0x02, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      0x02, 0x00, 0x3E, 0x00, 0x01, 0x00, 0x00, 0x00, 0x78, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00,
    ]
    @hex_viewer = Opal::UI::HexViewer.new(bytes: raw_bytes, base_address: 0x00400000_u64)
  end

  def title : String
    "Code Viewer & Hex Memory Inspector"
  end

  def category : String
    "Developer Tools"
  end

  def hints : String
    "[↑/↓] Scroll Code & Hex Preview"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "k"
      @code_view.scroll_up
      @hex_viewer.scroll_up
      true
    when "down", "j"
      @code_view.scroll_down
      @hex_viewer.scroll_down
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @code_view.scroll_up
      @hex_viewer.scroll_up
      true
    when Opal::Terminal::MouseButton::WheelDown
      @code_view.scroll_down
      @hex_viewer.scroll_down
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    half_w = (w - 6) // 2

    # Left: CodeView
    buffer.put_string(x + 2, y + 1, ">> Syntax Highlighted CodeView", fg: Opal::Color.cyan, bold: true)
    @code_view.render(buffer, x + 2, y + 3, half_w, h - 5)

    # Right: HexViewer
    divider_x = x + 2 + half_w
    (y + 1...y + h - 2).each do |div_y|
      buffer.put_char(divider_x, div_y, '│', fg: Opal::Color.bright_black)
    end

    hex_x = divider_x + 2
    buffer.put_string(hex_x, y + 1, "[?] Binary Memory Dump (HexViewer)", fg: Opal::Color.cyan, bold: true)
    @hex_viewer.render(buffer, hex_x, y + 3, (x + w) - hex_x - 2, h - 5)
  end
end

# -----------------------------------------------------------------------------
# Slide 12: Split Views & Layout Engine (Interactive App)
# -----------------------------------------------------------------------------
class LayoutsSlide < ShowcaseSlide
  property ratio : Float64 = 0.5

  def title : String
    "Split Views & Layout Engine"
  end

  def category : String
    "Layouts & Borders"
  end

  def hints : String
    "[←/→] Adjust Split Ratio (20% - 80%)"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "left", "h"
      @ratio = (@ratio - 0.05).clamp(0.2, 0.8)
      true
    when "right", "l"
      @ratio = (@ratio + 0.05).clamp(0.2, 0.8)
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @ratio = (@ratio + 0.05).clamp(0.2, 0.8)
      true
    when Opal::Terminal::MouseButton::WheelDown
      @ratio = (@ratio - 0.05).clamp(0.2, 0.8)
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press || event.action == Opal::Terminal::MouseAction::Motion
        cols, _ = Opal::Terminal.default_driver.size
        @ratio = (event.x.to_f / cols.to_f).clamp(0.2, 0.8)
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> Double-Buffered Split Layouts (Ratio: #{(@ratio * 100).to_i}%)", fg: Opal::Color.cyan, bold: true)
    cur_y += 2

    split_w = w - 4
    split_h = h - 5

    left_w = (split_w * @ratio).to_i
    right_w = split_w - left_w - 1

    # Left pane with rounded border
    left_box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("Left Pane\nNested VStack / HStack\nBorder: Rounded", fg: Opal::Color.green),
      border: :rounded,
      title: "Navigation"
    )
    left_box.render(buffer, x + 2, cur_y, left_w, split_h)

    # Right pane with double border
    right_box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("Right Pane\nContent Canvas\nBorder: Double\nUse [←/→] to slide!", fg: Opal::Color.yellow),
      border: :double,
      title: "Inspector"
    )
    right_box.render(buffer, x + 2 + left_w + 1, cur_y, right_w, split_h)
  end
end

# -----------------------------------------------------------------------------
# Slide 13: Tabs, Badges & Status Bars (Interactive App)
# -----------------------------------------------------------------------------
class TabsSlide < ShowcaseSlide
  getter tabs : Opal::UI::Tabs

  def initialize
    labels = ["Overview", "Telemetry", "Topology", "Security", "Config"]
    @tabs = Opal::UI::Tabs.from_labels(labels, active: 0)
    @tabs.pill_style = true
  end

  def title : String
    "Tabs, Badges & Navigation"
  end

  def category : String
    "Navigation UI"
  end

  def hints : String
    "[←/→] or [1-5] Switch Active Tab"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "left", "h"
      @tabs.prev_tab
      true
    when "right", "l"
      @tabs.next_tab
      true
    else
      if key.name.size == 1 && key.name[0].ascii_number?
        idx = key.name.to_i - 1
        if idx >= 0 && idx < @tabs.items.size
          @tabs.active_index = idx
          return true
        end
      end
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @tabs.prev_tab
      true
    when Opal::Terminal::MouseButton::WheelDown
      @tabs.next_tab
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        @tabs.next_tab
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Interactive Tabbed Navigation", fg: Opal::Color.cyan, bold: true)
    @tabs.render(buffer, x + 2, y + 3, w - 4, 1)

    card_y = y + 5
    card_h = h - 7

    # Card corresponding to active tab
    active_name = @tabs.active_tab.try(&.label) || "Overview"
    content_box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("Viewing pane: #{active_name}\n\nStatus Badges below:", fg: Opal::Color.white),
      border: :rounded,
      title: active_name
    )
    content_box.render(buffer, x + 2, card_y, w - 4, card_h)

    # Badges row
    badge_y = card_y + 4
    if badge_y < y + h - 2
      b1 = Opal::UI::Badge.new("LIVE", bg: :green, fg: :white)
      b2 = Opal::UI::Badge.new("STAGING", bg: :yellow, fg: :black)
      b3 = Opal::UI::Badge.new("TLS 1.3", bg: :cyan, fg: :black)
      b4 = Opal::UI::Badge.new("ENCRYPTED", bg: :magenta, fg: :white)

      b1.render(buffer, x + 5, badge_y, 10, 1)
      b2.render(buffer, x + 16, badge_y, 12, 1)
      b3.render(buffer, x + 29, badge_y, 12, 1)
      b4.render(buffer, x + 42, badge_y, 14, 1)
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 14: Modals & Backdrop Dimming (Interactive App)
# -----------------------------------------------------------------------------
class ModalsSlide < ShowcaseSlide
  getter modal : Opal::UI::Modal

  def initialize
    @modal = Opal::UI::Modal.new(
      title: "Cluster Failover Confirmation",
      message: "Node 'worker-04' failed health checks.\nInitiate automatic failover to replica zone?",
      buttons: ["Cancel", "Inspect Logs", "Confirm Failover"],
      selected_button: 2
    )
  end

  def title : String
    "Modals & Layer Blending"
  end

  def category : String
    "Overlays & Blitting"
  end

  def hints : String
    "[←/→] Select Dialog Action Button"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "left", "h"
      @modal.selected_button = Math.max(0, @modal.selected_button - 1)
      true
    when "right", "l"
      @modal.selected_button = Math.min(@modal.buttons.size - 1, @modal.selected_button + 1)
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    # Render background pattern to demonstrate backdrop dimming
    (y...y + h).each do |bg_y|
      row_text = "  Telemetry feed #{bg_y} :: Node cpu=44% mem=1200MB disk=78% net=10Gbps | " * 3
      buffer.put_string(x, bg_y, row_text, fg: Opal::Color.bright_black)
    end

    # Render modal blit overlay
    @modal.render(buffer, x, y, w, h)
  end
end

# -----------------------------------------------------------------------------
# Slide 15: Toast Notification Queue (Interactive App)
# -----------------------------------------------------------------------------
class ToastsSlide < ShowcaseSlide
  getter toast_mgr : Opal::UI::ToastManager

  def initialize
    @toast_mgr = Opal::UI::ToastManager.new
    @toast_mgr.add("Database Synced", "PostgreSQL pool healthy (5ms ping)", level: :success)
    @toast_mgr.add("Build Succeeded", "All 156 specs passed (100%)", level: :info)
  end

  def title : String
    "Toast Notification Queue"
  end

  def category : String
    "Overlays & Alerts"
  end

  def hints : String
    "[1-4] Spawn Toast Notification   [c] Clear Stack"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1"
      @toast_mgr.add("System Notice", "Cache warmed up successfully", level: :info)
      true
    when "2"
      @toast_mgr.add("Deployment Complete", "Release v2.4.0 live across all pods", level: :success)
      true
    when "3"
      @toast_mgr.add("Memory Alert", "Free memory dropped below 15%", level: :warning)
      true
    when "4"
      @toast_mgr.add("Connection Failed", "Timeout connecting to auth proxy", level: :error)
      true
    when "c"
      @toast_mgr.toasts.clear
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Floating Toast Notifications Stack", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 3, "Press [1], [2], [3], [4] to trigger notifications.", fg: Opal::Color.white)
    buffer.put_string(x + 2, y + 4, "Active Toasts: #{@toast_mgr.size}", fg: Opal::Color.yellow)

    # Render floating toast overlay in top-right
    @toast_mgr.render_overlay(buffer, position: :top_right)
  end
end

# -----------------------------------------------------------------------------
# Slide 16: Command Palette (Spotlight Launcher) (Interactive App)
# -----------------------------------------------------------------------------
class CommandPaletteSlide < ShowcaseSlide
  getter palette : Opal::UI::CommandPalette
  property feedback : String = "Press keys to search actions..."

  def initialize
    @palette = Opal::UI::CommandPalette.new
    @palette.add("git:commit", "Commit Working Changes", category: "Git", shortcut: "Ctrl+C") { @feedback = "Executed: Git Commit" }
    @palette.add("git:push", "Push to Origin / Main", category: "Git", shortcut: "Ctrl+P") { @feedback = "Executed: Git Push" }
    @palette.add("file:open", "Open File Dialog Explorer", category: "File", shortcut: "Ctrl+O") { @feedback = "Executed: Open File" }
    @palette.add("file:save", "Save Active Document", category: "File", shortcut: "Ctrl+S") { @feedback = "Executed: File Saved" }
    @palette.add("theme:catppuccin", "Switch Theme: Catppuccin Mocha", category: "Theme") { @feedback = "Theme Switched!" }
    @palette.add("build:release", "Compile Release Binary (Optimized)", category: "Build", shortcut: "Ctrl+B") { @feedback = "Build Started..." }
  end

  def title : String
    "Command Palette (Spotlight Launcher)"
  end

  def category : String
    "Quick Launcher"
  end

  def hints : String
    "[Type] Search Commands   [↑/↓] Select   [Enter] Execute"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "up", "ctrl+p"
      @palette.cursor_up
      true
    when "down", "ctrl+n"
      @palette.cursor_down
      true
    when "backspace"
      @palette.backspace
      true
    when "enter"
      if action = @palette.execute_selected
        @feedback = "Triggered action: #{action.title}"
      end
      true
    else
      if key.name.size == 1 && !key.ctrl? && !key.alt?
        @palette.append_char(key.name[0])
        true
      else
        false
      end
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Spotlight Command Palette", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 2, @feedback, fg: Opal::Color.green, italic: true)

    @palette.render(buffer, x + 2, y + 4, w - 4, h - 6)
  end
end

# -----------------------------------------------------------------------------
# Slide 17: Ghost-Text Autocomplete & Line Editor (Interactive App)
# -----------------------------------------------------------------------------
class AutocompleteSlide < ShowcaseSlide
  getter input : Opal::Input::TextInput
  getter engine : Opal::Input::Autocomplete

  def initialize
    commands = [
      "crystal build --release src/opal.cr",
      "crystal run examples/08_dataviz_dashboard.cr",
      "crystal spec --verbose",
      "docker compose up -d",
      "git checkout -b feat/tui-showcase",
      "git commit -m 'feat: full formed tui showcase demo'",
      "shards install",
      "systemctl restart k8s-mesh",
    ]
    @engine = Opal::Input::Autocomplete.new(commands)
    @input = Opal::Input::TextInput.new(prompt: "lapis > ", autocomplete: @engine)
  end

  def title : String
    "Ghost-Text Autocomplete & Input DSL"
  end

  def category : String
    "Line Editor & Prompts"
  end

  def hints : String
    "[Type] Input   [Tab / →] Accept Ghost Completion   [Backspace] Delete"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @input.handle_key(key)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> Fish/Zsh-Style Inline Ghost-Text Autocomplete", fg: Opal::Color.cyan, bold: true)
    cur_y += 2

    buffer.put_string(x + 2, cur_y, "Interactive Prompt Input:", fg: Opal::Color.white)
    cur_y += 2

    # Draw prompt shell box
    box_w = Math.min(w - 4, 70)
    buffer.put_string(x + 2, cur_y, "┌" + "─" * (box_w - 2) + "┐", fg: Opal::Color.cyan)
    cur_y += 1

    buffer.put_string(x + 2, cur_y, "│ lapis > ", fg: Opal::Color.cyan, bold: true)
    input_x = x + 12

    val = @input.value
    buffer.put_string(input_x, cur_y, val, fg: Opal::Color.bright_white)

    # Ghost text preview in muted gray
    if ghost = @input.current_ghost_text
      buffer.put_string(input_x + Opal::VisualWidth.width(val), cur_y, ghost, fg: Opal::Color.bright_black, italic: true)
    end

    buffer.put_string(x + 2 + box_w - 1, cur_y, "│", fg: Opal::Color.cyan)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "└" + "─" * (box_w - 2) + "┘", fg: Opal::Color.cyan)
    cur_y += 2

    buffer.put_string(x + 2, cur_y, "Current Value: '#{@input.value}'", fg: Opal::Color.yellow)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "Press [Tab] or [Right] to expand ghost completion instantly.", fg: Opal::Color.bright_black)
  end
end

# -----------------------------------------------------------------------------
# Slide 18: Theme Engine & Semantic Colors (Interactive App)
# -----------------------------------------------------------------------------
class ThemesSlide < ShowcaseSlide
  THEMES = [:catppuccin_mocha, :dracula, :tokyo_night, :nord, :gruvbox]
  property theme_idx : Int32 = 0

  def title : String
    "Theme Engine & Semantic Colors"
  end

  def category : String
    "Design System"
  end

  def hints : String
    "[Space] Cycle Color Themes"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "space", "enter", "right"
      @theme_idx = (@theme_idx + 1) % THEMES.size
      Opal.theme = THEMES[@theme_idx]
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    current_name = THEMES[@theme_idx]
    theme = Opal.theme

    buffer.put_string(x + 2, y + 1, ">> Active Palette: :#{current_name} (Press Space to Switch)", fg: theme.primary, bold: true)
    buffer.put_string(x + 2, y + 2, "Semantic color tokens ensure consistent aesthetics across full applications.", fg: theme.text_muted)

    # Swatches row
    tokens = [
      {"Primary", theme.primary},
      {"Secondary", theme.secondary},
      {"Accent", theme.accent},
      {"Success", theme.success},
      {"Warning", theme.warning},
      {"Danger", theme.danger},
      {"Info", theme.info},
    ]

    col_x = x + 2
    tokens.each do |t_name, t_color|
      break if col_x + 10 >= x + w
      buffer.put_string(col_x, y + 4, "██████", fg: t_color)
      buffer.put_string(col_x, y + 5, t_name, fg: t_color, bold: true)
      col_x += 10
    end

    # Themed Box
    styled_box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("The entire UI inherits these semantic tokens seamlessly!", fg: theme.text),
      border: :rounded,
      border_fg: theme.border,
      title: "Themed Container",
      title_fg: theme.accent
    )
    styled_box.render(buffer, x + 2, y + 8, Math.min(w - 4, 60), 6)
  end
end

# -----------------------------------------------------------------------------
# Slide 19: Terminal Capabilities & OSC Integration (Interactive App)
# -----------------------------------------------------------------------------
class TerminalOscSlide < ShowcaseSlide
  property copied_status : String? = nil

  def title : String
    "Terminal Capabilities & OSC 8 / OSC 52"
  end

  def category : String
    "Terminal Protocols"
  end

  def hints : String
    "[c] Copy to System Clipboard (OSC 52)"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "c"
      Opal.copy_to_clipboard("OPAL_SECRET_TOKEN_993478a")
      @copied_status = "[OK] Copied 'OPAL_SECRET_TOKEN_993478a' to OS desktop clipboard via OSC 52!"
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Terminal Environment & Hardware Query", fg: Opal::Color.cyan, bold: true)

    cur_y = y + 3
    Opal.terminal do |term|
      buffer.put_string(x + 4, cur_y, "Dimensions:      #{term.columns} columns x #{term.rows} rows", fg: Opal::Color.white)
      cur_y += 1
      buffer.put_string(x + 4, cur_y, "Color Profile:   #{term.color_profile}", fg: Opal::Color.white)
      cur_y += 1
      buffer.put_string(x + 4, cur_y, "TrueColor:       #{term.truecolor? ? "Supported (24-bit)" : "Fallback (256/16)"}", fg: Opal::Color.green)
      cur_y += 1
      buffer.put_string(x + 4, cur_y, "Mouse Support:   #{term.supports_mouse? ? "Yes (SGR extended)" : "No"}", fg: Opal::Color.white)
      cur_y += 1
      buffer.put_string(x + 4, cur_y, "OS Platform:     #{term.windows? ? "Native Windows Console" : "POSIX termios"}", fg: Opal::Color.cyan)
      cur_y += 2
    end

    buffer.put_string(x + 2, cur_y, ">> Clickable Terminal Hyperlinks (OSC 8):", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 4, cur_y, Opal.hyperlink("Open GitHub Repository", "https://github.com/sol-vin/opal"), fg: Opal::Color.bright_cyan, underline: true)
    cur_y += 2

    buffer.put_string(x + 2, cur_y, ">> Desktop Clipboard Integration (OSC 52):", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 4, cur_y, "Press [c] to copy secret auth token to OS clipboard.", fg: Opal::Color.yellow)
    cur_y += 1

    if status = @copied_status
      buffer.put_string(x + 4, cur_y, status, fg: Opal::Color.green, bold: true)
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 20: The Elm Architecture (TEA) Reactive Engine (Interactive App)
# -----------------------------------------------------------------------------
class TeaEngineSlide < ShowcaseSlide
  property count : Int32 = 0
  property ticks : Int32 = 0
  property? auto_tick : Bool = true

  def title : String
    "The Elm Architecture (TEA) Reactive Engine"
  end

  def category : String
    "Reactive Runtime"
  end

  def hints : String
    "[+/-] Adjust Count   [Space] Pause Auto-Tick   [r] Reset"
  end

  def tick : Nil
    @ticks += 1 if @auto_tick
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "+", "=", "up"
      @count += 1
      true
    when "-", "down"
      @count -= 1
      true
    when "space", " "
      @auto_tick = !@auto_tick
      true
    when "r"
      @count = 0
      @ticks = 0
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, ">> Pure Elm Architecture (Model -> Update -> View)", fg: Opal::Color.cyan, bold: true)
    buffer.put_string(x + 2, y + 2, "Predictable state transitions inspired by Bubble Tea with background Cmd timers.", fg: Opal::Color.white)

    box = Opal::UI::Box.new(
      child: Opal::UI::Text.new(
        "Current Counter State: #{@count}\n" \
        "Background Ticks:     #{@ticks} (#{(@auto_tick ? "RUNNING" : "PAUSED")})\n\n" \
        "Controls:\n" \
        "  [+] Increment  [-] Decrement  [Space] Toggle Tick  [r] Reset",
        fg: Opal::Color.bright_white
      ),
      border: :rounded,
      title: "TEA State Machine"
    )
    box.render(buffer, x + 2, y + 4, Math.min(w - 4, 60), 8)
  end
end

# -----------------------------------------------------------------------------
# Slide 21: Grand Finale & Conclusion (Markdown Summary)
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Slide 21: Text Shader Engine & Compositing FX (Interactive App - NEW)
# -----------------------------------------------------------------------------
class TextShaderSlide < ShowcaseSlide
  property mode : Int32 = 1
  property time : Float64 = 0.0
  property frame : UInt64 = 0_u64
  property? animating : Bool = true
  property? bouncing : Bool = true

  # Bouncing window coordinates & velocities
  @win_x : Float64 = 6.0
  @win_y : Float64 = 3.0
  @vel_x : Float64 = 0.6
  @vel_y : Float64 = 0.3

  # Pre-cached shader passes for zero-allocation rendering per frame
  @matrix_pass = Opal::Shader::MatrixPass.new(speed: 1.2, density: 0.25, preserve_text: false)
  @plasma_pass = Opal::Shader::PlasmaPass.new(scale: 0.14, speed: 1.6)
  @fire_pass = Opal::Shader::FirePass.new(speed: 1.2)
  @starfield_pass = Opal::Shader::StarfieldPass.new(speed: 1.4, count: 70, preserve_text: false)
  @ripple_pass = Opal::Shader::RipplePass.new(speed: 2.2, frequency: 0.35, amplitude: 2.0)
  @tunnel_pass = Opal::Shader::TunnelPass.new(speed: 1.4, rotation_speed: 0.6)
  @sphere_pass = Opal::Shader::RaymarchSpherePass.new(speed: 1.2, radius: 0.82)
  @voronoi_pass = Opal::Shader::VoronoiPass.new(speed: 0.8, scale: 0.18)
  @mountain_pass = Opal::Shader::FractalLandscapePass.new(speed: 1.2)
  @audio_pass = Opal::Shader::AudioVisualizerPass.new(speed: 1.2, bar_count: 14)
  @crt_pass = Opal::Shader::CrtPass.new(intensity: 0.45, scanline_gap: 2, phosphor_tint: Opal::Color.green)
  @glitch_pass = Opal::Shader::GlitchPass.new(intensity: 0.28, slice_height: 3)
  @composite_crt = Opal::Shader::CrtPass.new(intensity: 0.35, scanline_gap: 2)
  @composite_vignette = Opal::Shader::VignettePass.new(radius: 0.85, falloff: 0.4)

  SHADERS = [
    {id: 1, key: "1", name: "Matrix Rain", cat: "Procedural", desc: "Digital rain streams with glowing green trails"},
    {id: 2, key: "2", name: "Retro CRT", cat: "Post-Process", desc: "Phosphor glow, scanlines & subtle flicker"},
    {id: 3, key: "3", name: "TrueColor Plasma", cat: "Procedural", desc: "Sine wave interference plasma with 24-bit color"},
    {id: 4, key: "4", name: "Glitch & Tearing", cat: "Post-Process", desc: "Horizontal slice displacement & chromatic shift"},
    {id: 5, key: "5", name: "Fire Dispersion", cat: "Particle", desc: "Ascending heat dispersion with temperature ramp"},
    {id: 6, key: "6", name: "3D Starfield", cat: "3D Motion", desc: "Perspective depth star projection with speed trails"},
    {id: 7, key: "7", name: "Water Ripple", cat: "Displacement", desc: "Sinusoidal caustic water wave displacement"},
    {id: 8, key: "8", name: "Cyber Tunnel", cat: "3D Motion", desc: "Infinite perspective polar coordinate cyber tunnel"},
    {id: 9, key: "9", name: "Raymarch Sphere", cat: "Raymarch 3D", desc: "Dynamic orbiting light, specular & ASCII ramp"},
    {id: 10, key: "0", name: "Voronoi Grid", cat: "Procedural", desc: "Worley cellular noise with glowing neon borders"},
    {id: 11, key: "A", name: "Fractal Mountain", cat: "Landscape", desc: "Parallax mountain ridges under starry twilight"},
    {id: 12, key: "B", name: "Audio Equalizer", cat: "Audio FX", desc: "Dynamic 16-band VU-meters with peak hold"},
    {id: 13, key: "C", name: "Composite FX", cat: "Composite", desc: "Chained Plasma + CRT Scanlines + Vignette"},
  ]

  def title : String
    "Text Shader Engine & Compositing FX"
  end

  def category : String
    "Post-Processing Engine (New)"
  end

  def hints : String
    "[↑/↓] or [1-9, 0, A, B, C] Select Shader   [Space] Pause   [B] Toggle Bounce"
  end

  def tick : Nil
    if @animating
      @time += 0.05
      @frame += 1_u64
    end

    if @bouncing && @animating
      card_w = 40.0
      card_h = 7.0
      min_x = 36.0
      max_x = 100.0 - card_w
      min_y = 4.0
      max_y = 22.0 - card_h

      if max_x > min_x
        @win_x += @vel_x
        if @win_x <= min_x
          @win_x = min_x
          @vel_x = @vel_x.abs
        elsif @win_x >= max_x
          @win_x = max_x
          @vel_x = -@vel_x.abs
        end
      end

      if max_y > min_y
        @win_y += @vel_y
        if @win_y <= min_y
          @win_y = min_y
          @vel_y = @vel_y.abs
        elsif @win_y >= max_y
          @win_y = max_y
          @vel_y = -@vel_y.abs
        end
      end
    end
  end

  def select_shader(idx : Int32) : Bool
    if idx >= 1 && idx <= SHADERS.size
      @mode = idx
      true
    else
      false
    end
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name.downcase
    when "up", "k"
      @mode = (@mode <= 1 ? SHADERS.size : @mode - 1)
      true
    when "down", "j"
      @mode = (@mode >= SHADERS.size ? 1 : @mode + 1)
      true
    when "1" then select_shader(1)
    when "2" then select_shader(2)
    when "3" then select_shader(3)
    when "4" then select_shader(4)
    when "5" then select_shader(5)
    when "6" then select_shader(6)
    when "7" then select_shader(7)
    when "8" then select_shader(8)
    when "9" then select_shader(9)
    when "0" then select_shader(10)
    when "a" then select_shader(11)
    when "b" then select_shader(12)
    when "c" then select_shader(13)
    when "t"
      @bouncing = !@bouncing
      true
    when "space", " "
      @animating = !@animating
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @mode = (@mode <= 1 ? SHADERS.size : @mode - 1)
      true
    when Opal::Terminal::MouseButton::WheelDown
      @mode = (@mode >= SHADERS.size ? 1 : @mode + 1)
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        # Check if clicking on menu item on left pane (x: 2..32, y: 3..16)
        if event.x >= 2 && event.x <= 34 && event.y >= 4 && event.y < 4 + SHADERS.size
          clicked_idx = event.y - 4 + 1
          select_shader(clicked_idx)
          true
        else
          @bouncing = !@bouncing
          true
        end
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    active_shader = SHADERS[@mode - 1] rescue SHADERS[0]

    buffer.put_string(x + 2, cur_y, ">> Text Shader Engine ── Mode [#{@mode}/#{SHADERS.size}]: #{active_shader[:name]} [#{active_shader[:cat]}]", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, active_shader[:desc], fg: Opal::Color.bright_black, italic: true)
    cur_y += 1

    menu_w = 32
    content_x = x + menu_w + 3
    content_w = Math.max(20, w - menu_w - 5)
    content_h = Math.max(10, h - 4)

    # 1. Left Menu: Shaders list
    menu_box = Opal::UI::Box.new(
      border: :rounded,
      border_fg: Opal::Color.bright_black,
      title: "Presets (#{SHADERS.size})",
      title_fg: Opal::Color.cyan
    )
    menu_box.render(buffer, x + 2, cur_y, menu_w, content_h)

    SHADERS.each_with_index do |s, idx|
      item_y = cur_y + 1 + idx
      break if item_y >= cur_y + content_h - 1

      is_selected = (s[:id] == @mode)
      prefix = is_selected ? "> [#{s[:key]}] " : "  [#{s[:key]}] "
      line_text = "#{prefix}#{s[:name]}"

      if is_selected
        buffer.put_string(x + 3, item_y, line_text.ljust(menu_w - 2), fg: Opal::Color.black, bg: Opal::Color.bright_cyan, bold: true)
      else
        buffer.put_string(x + 3, item_y, line_text, fg: Opal::Color.white)
      end
    end

    # 2. Right Canvas: Viewport for shaders
    viewport_region = Opal::Shader::Rect.new(content_x, cur_y, content_w, content_h)

    # Generate dense test detail pattern for post-processing shaders (CRT, Glitch, Ripple, Composite)
    needs_detail = [2, 4, 7, 13].includes?(@mode)
    if needs_detail
      # Render rich diagnostic detail grid
      (0...content_h).each do |dy|
        py = cur_y + dy
        (0...content_w).each do |dx|
          px = content_x + dx
          # Diagnostic pattern
          if dy == 0 || dy == content_h - 1
            buffer.put_char(px, py, '═', fg: Opal::Color.bright_black)
          elsif dx == 0 || dx == content_w - 1
            buffer.put_char(px, py, '║', fg: Opal::Color.bright_black)
          elsif dy == 2
            buffer.put_string(content_x + 2, py, "SYS DIAGNOSTIC MATRIX // KERNEL 5.15", fg: Opal::Color.green, bold: true)
            break
          elsif dy == 3
            buffer.put_string(content_x + 2, py, "── MEMORY BUS ────────────────────────────", fg: Opal::Color.bright_black)
            break
          elsif dy == 4
            buffer.put_string(content_x + 2, py, "0x0040A0: 48 89 E5 48 83 EC 20 48 8D 05 12", fg: Opal::Color.bright_white)
            break
          elsif dy == 5
            buffer.put_string(content_x + 2, py, "0x0040B0: E8 B4 FE FF FF B8 00 00 00 00 C9", fg: Opal::Color.bright_white)
            break
          elsif dy == 7
            buffer.put_string(content_x + 2, py, "VECTOR OSCILLOSCOPE [CH1/CH2]:", fg: Opal::Color.yellow, bold: true)
            break
          elsif dy == 8
            # Oscilloscope wave
            sine_w = Math.sin(dx * 0.15 + @time * 2.0)
            char = sine_w > 0.5 ? '▲' : (sine_w < -0.5 ? '▼' : '─')
            buffer.put_char(px, py, char, fg: Opal::Color.cyan)
          elsif dy == 10
            buffer.put_string(content_x + 2, py, "CORE LOAD:  [████████████░░░░░░░░] 60%", fg: Opal::Color.bright_cyan)
            break
          elsif dy == 11
            buffer.put_string(content_x + 2, py, "BUS FLUX:   [████████████████░░░░] 80%", fg: Opal::Color.green)
            break
          elsif dy == 13
            buffer.put_string(content_x + 2, py, "CALIBRATION: [RGB] R:255 G:180 B:40", fg: Opal::Color.magenta)
            break
          end
        end
      end
    end

    # Apply active shader
    case @mode
    when 1
      @matrix_pass.region = viewport_region
      @matrix_pass.apply(buffer, buffer, @time, @frame)
    when 3
      @plasma_pass.region = viewport_region
      @plasma_pass.apply(buffer, buffer, @time, @frame)
    when 5
      @fire_pass.region = viewport_region
      @fire_pass.apply(buffer, buffer, @time, @frame)
    when 6
      @starfield_pass.region = viewport_region
      @starfield_pass.apply(buffer, buffer, @time, @frame)
    when 7
      @ripple_pass.region = viewport_region
      @ripple_pass.apply(buffer, buffer, @time, @frame)
    when 8
      @tunnel_pass.region = viewport_region
      @tunnel_pass.apply(buffer, buffer, @time, @frame)
    when 9
      @sphere_pass.region = viewport_region
      @sphere_pass.apply(buffer, buffer, @time, @frame)
    when 10
      @voronoi_pass.region = viewport_region
      @voronoi_pass.apply(buffer, buffer, @time, @frame)
    when 11
      @mountain_pass.region = viewport_region
      @mountain_pass.apply(buffer, buffer, @time, @frame)
    when 12
      @audio_pass.region = viewport_region
      @audio_pass.apply(buffer, buffer, @time, @frame)
    when 13
      @plasma_pass.region = viewport_region
      @plasma_pass.apply(buffer, buffer, @time, @frame)
    end

    # Render floating telemetry window if enabled
    if @bouncing
      card_w = Math.min(38, Math.max(10, content_w - 2))
      card_h = Math.min(7, Math.max(3, content_h - 2))
      min_clamp_x = content_x + 1
      max_clamp_x = Math.max(min_clamp_x, content_x + content_w - card_w - 1)
      win_x = (x + @win_x.to_i).clamp(min_clamp_x, max_clamp_x)

      min_clamp_y = cur_y + 1
      max_clamp_y = Math.max(min_clamp_y, cur_y + content_h - card_h - 1)
      win_y = (y + @win_y.to_i).clamp(min_clamp_y, max_clamp_y)

      b = Opal::UI::Box.new(
        child: Opal::UI::Text.new(
          "TELEMETRY NODE // ACTIVE\n" \
          "Throughput: 10 Gbps | Time: #{@time.round(1)}s\n" \
          "Frame: ##{@frame} | Layer: Opaque\n" \
          "[B] Toggle Window",
          fg: Opal::Color.bright_white
        ),
        border: :rounded,
        border_fg: Opal::Color.cyan,
        title: "Node Status",
        title_fg: Opal::Color.bright_cyan,
        bg: Opal::Color.rgb(18, 22, 34)
      )
      b.render(buffer, win_x, win_y, card_w, card_h)
    end

    # Screen-space post-processing passes applied after base rendering
    case @mode
    when 2
      @crt_pass.region = viewport_region
      @crt_pass.apply(buffer, buffer, @time, @frame)
    when 4
      @glitch_pass.region = viewport_region
      @glitch_pass.apply(buffer, buffer, @time, @frame)
    when 13
      @composite_crt.region = viewport_region
      @composite_crt.apply(buffer, buffer, @time, @frame)
      @composite_vignette.region = viewport_region
      @composite_vignette.apply(buffer, buffer, @time, @frame)
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 22: 2D/3D Color Spectrum & Rotatable Cube (Interactive App - NEW)
# -----------------------------------------------------------------------------
class ColorPicker3DSlide < ShowcaseSlide
  getter picker : Opal::UI::ColorPicker3D

  def initialize
    @picker = Opal::UI::ColorPicker3D.new(auto_rotate: false)
  end

  def title : String
    "2D/3D Color Spectrum & Rotatable Cube"
  end

  def category : String
    "3D Graphics & Color Space (New)"
  end

  def hints : String
    "[Right-Drag] Rotate 3D   [Left-Click] Pick Color   [Wheel] Lightness   [M] Shape   [Space] Auto-Spin"
  end

  def tick : Nil
    @picker.tick(0.04)
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @picker.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @picker.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @picker.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 25: Image to ASCII Art & Interpolation (Interactive App - NEW)
# -----------------------------------------------------------------------------
class AsciiImageSlide < ShowcaseSlide
  property mode : Opal::UI::AsciiRenderMode = Opal::UI::AsciiRenderMode::HalfBlock
  property interpolation : Opal::Image::Interpolation = Opal::Image::Interpolation::Bilinear
  property selected_image : Int32 = 1
  property? colorize : Bool = true

  @gem_img : Opal::Image::PixelBuffer
  @landscape_img : Opal::Image::PixelBuffer
  @spectrum_img : Opal::Image::PixelBuffer

  def initialize
    @gem_img = Opal::Image::PixelBuffer.sample_gem(38, 38)
    @landscape_img = Opal::Image::PixelBuffer.sample_landscape(46, 30)

    # Generate HSV color wheel/spectrum
    @spectrum_img = Opal::Image::PixelBuffer.new(38, 38)
    cx = 19.0
    cy = 19.0
    radius = 18.0
    (0...38).each do |py|
      dy = py.to_f - cy
      (0...38).each do |px|
        dx = px.to_f - cx
        dist = Math.sqrt(dx * dx + dy * dy)
        if dist <= radius
          angle = Math.atan2(dy, dx)
          hue = (angle / (2.0 * Math::PI) + 0.5) * 360.0
          sat = (dist / radius).clamp(0.0, 1.0)
          val = 1.0
          c = Opal::Color.hsv(hue, sat, val)
          @spectrum_img.set(px, py, c)
        else
          @spectrum_img.set(px, py, Opal::Color.rgb(10, 12, 18))
        end
      end
    end
  end

  def title : String
    "Image to ASCII Art & Interpolation"
  end

  def category : String
    "Graphics & Image Processing (New)"
  end

  def hints : String
    "[M] HalfBlock / NearestChar   [I] Bilinear / Nearest   [1-3] Switch Image   [C] Colorize"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "m"
      @mode = (@mode == Opal::UI::AsciiRenderMode::HalfBlock ? Opal::UI::AsciiRenderMode::NearestChar : Opal::UI::AsciiRenderMode::HalfBlock)
      true
    when "i"
      @interpolation = (@interpolation == Opal::Image::Interpolation::Bilinear ? Opal::Image::Interpolation::Nearest : Opal::Image::Interpolation::Bilinear)
      true
    when "1"
      @selected_image = 1
      true
    when "2"
      @selected_image = 2
      true
    when "3"
      @selected_image = 3
      true
    when "c"
      @colorize = !@colorize
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @selected_image = (@selected_image == 1 ? 3 : @selected_image - 1)
      true
    when Opal::Terminal::MouseButton::WheelDown
      @selected_image = (@selected_image == 3 ? 1 : @selected_image + 1)
      true
    when Opal::Terminal::MouseButton::Left
      if event.action == Opal::Terminal::MouseAction::Press
        @mode = (@mode == Opal::UI::AsciiRenderMode::HalfBlock ? Opal::UI::AsciiRenderMode::NearestChar : Opal::UI::AsciiRenderMode::HalfBlock)
        true
      else
        false
      end
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    mode_desc = (@mode == Opal::UI::AsciiRenderMode::HalfBlock) ? "Half-Block (▀ 2px/cell)" : "Nearest-Char (Optical Density)"
    interp_desc = (@interpolation == Opal::Image::Interpolation::Bilinear) ? "Bilinear Interpolation" : "Nearest Neighbor"
    img_name = case @selected_image
               when 1 then "Opal Faceted Gemstone"
               when 2 then "Twilight Mountains Sunset"
               when 3 then "TrueColor HSV Spectrum Wheel"
               else        "Custom"
               end

    buffer.put_string(x + 2, cur_y, ">> Image to ASCII Engine ── [Mode: #{mode_desc}]", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "Filtering: #{interp_desc} │ Subject: #{img_name} │ Color: #{(@colorize ? "TrueColor" : "Monochrome")}", fg: Opal::Color.bright_black)
    cur_y += 1

    active_img = case @selected_image
                 when 1 then @gem_img
                 when 2 then @landscape_img
                 else        @spectrum_img
                 end

    # Left pane: Render ASCII image inside styled box
    img_w = 40
    img_h = Math.min(h - 4, 18)

    img_box = Opal::UI::Box.new(
      child: Opal::UI::AsciiImage.new(
        image: active_img,
        mode: @mode,
        interpolation: @interpolation,
        colorize: @colorize,
        ramp: Opal::UI::AsciiImage::RAMP_STANDARD,
        bg: Opal::Color.rgb(10, 12, 18)
      ),
      border: :rounded,
      border_fg: Opal::Color.cyan,
      title: "ASCII Viewport",
      bg: Opal::Color.rgb(10, 12, 18)
    )
    img_box.render(buffer, x + 2, cur_y, img_w, img_h)

    # Right pane: Inspector with specification explanation
    info_x = x + 2 + img_w + 2
    info_w = Math.max(10, w - img_w - 6)

    info_card = Opal::UI::Box.new(
      child: Opal::UI::Text.new(
        "ALGORITHM & RENDERING MODES:\n\n" \
        "1. Half-Block Mode (▀):\n" \
        "   Combines top sub-pixel (fg)\n" \
        "   and bottom sub-pixel (bg)\n" \
        "   per cell for 2x vertical resolution.\n\n" \
        "2. Nearest-Char Mode:\n" \
        "   Evaluates Rec.601 luminance:\n" \
        "   L = 0.299R + 0.587G + 0.114B\n" \
        "   and maps to density ramp:\n" \
        "   [ .:-=+*#%@].\n\n" \
        "3. Bilinear Interpolation:\n" \
        "   Continuous 4-point area weighting\n" \
        "   for smooth anti-aliased scaling.",
        fg: Opal::Color.bright_white
      ),
      border: :rounded,
      border_fg: Opal::Color.bright_black,
      title: "Specification",
      bg: Opal::Color.rgb(14, 18, 26)
    )
    info_card.render(buffer, info_x, cur_y, info_w, img_h)
  end
end

# -----------------------------------------------------------------------------
# Slide 26: Interactive Controls Studio (Buttons, Dropdown, ScrollBars - NEW)
# -----------------------------------------------------------------------------
class ControlsSlide < ShowcaseSlide
  getter btn_primary : Opal::UI::Button
  getter btn_secondary : Opal::UI::Button
  getter btn_toggle : Opal::UI::Button
  getter btn_danger : Opal::UI::Button
  getter dropdown : Opal::UI::Dropdown
  getter v_scrollbar : Opal::UI::ScrollBar
  getter h_scrollbar : Opal::UI::ScrollBar
  property active_control_idx : Int32 = 0
  property status_msg : String = "Interact with controls using Tab, Enter, Space, or Mouse Click/Drag."

  def initialize
    @btn_primary = Opal::UI::Button.new("Deploy Service", variant: :primary)
    @btn_secondary = Opal::UI::Button.new("View Logs", variant: :secondary)
    @btn_toggle = Opal::UI::Button.new("Auto-Scale", variant: :toggle)
    @btn_danger = Opal::UI::Button.new("Purge Cache", variant: :danger)

    @dropdown = Opal::UI::Dropdown.new(
      items: ["Production (us-east-1)", "Staging (eu-central-1)", "Development (local)", "Disaster Recovery (ap-northeast)"],
      selected_index: 0
    )

    @v_scrollbar = Opal::UI::ScrollBar.new(orientation: Opal::UI::ScrollBar::Orientation::Vertical, min_value: 0, max_value: 100, value: 15, page_size: 20)
    @h_scrollbar = Opal::UI::ScrollBar.new(orientation: Opal::UI::ScrollBar::Orientation::Horizontal, min_value: 0, max_value: 100, value: 30, page_size: 25)

    @btn_primary.on_click { @status_msg = "Primary Button Clicked: Deployment Triggered!" }
    @btn_secondary.on_click { @status_msg = "Secondary Button Clicked: Streaming Logs..." }
    @btn_toggle.on_click { |b| @status_msg = "Auto-Scale Toggled: #{b.active? ? "ENABLED" : "DISABLED"}" }
    @btn_danger.on_click { @status_msg = "Danger Button Clicked: Cache Cleared!" }
    @dropdown.on_change = ->(idx : Int32, item : String) {
      @status_msg = "Dropdown Selected: #{item} (index #{idx})"
      nil
    }
    @v_scrollbar.on_change { |off| @status_msg = "Vertical ScrollBar moved to offset #{off}" }
    @h_scrollbar.on_change { |off| @status_msg = "Horizontal ScrollBar moved to offset #{off}" }

    @btn_primary.focus
  end

  def title : String
    "Interactive UI Controls"
  end

  def category : String
    "Controls & Widgets (New)"
  end

  def hints : String
    "[Tab] Next Control   [Enter/Space] Activate / Toggle   [↑/↓] Dropdown/Scroll   [Mouse] Click & Drag"
  end

  private def controls
    [@btn_primary, @btn_secondary, @btn_toggle, @btn_danger, @dropdown, @v_scrollbar, @h_scrollbar]
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    if key.name == "tab"
      controls[@active_control_idx].unfocus
      @active_control_idx = (key.shift? ? @active_control_idx - 1 : @active_control_idx + 1)
      @active_control_idx = (@active_control_idx % controls.size + controls.size) % controls.size
      controls[@active_control_idx].focus
      return true
    end

    controls[@active_control_idx].handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    [@dropdown, @v_scrollbar, @h_scrollbar, @btn_primary, @btn_secondary, @btn_toggle, @btn_danger].each do |c|
      if c.handle_mouse(event)
        idx = controls.index(c)
        if idx && idx != @active_control_idx
          controls[@active_control_idx].unfocus
          @active_control_idx = idx
          c.focus
        end
        return true
      end
    end
    false
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> Interactive Controls Studio ── Buttons, Dropdowns & ScrollBars", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "Status: #{@status_msg}", fg: Opal::Color.green, italic: true)
    cur_y += 2

    col1_w = (w - 8) // 3
    b_card = Opal::UI::Box.new(border: :rounded, title: "Button Variants", border_fg: Opal::Color.cyan)
    b_card.render(buffer, x + 2, cur_y, col1_w, 14)

    @btn_primary.render(buffer, x + 4, cur_y + 2, col1_w - 4, 1)
    @btn_secondary.render(buffer, x + 4, cur_y + 4, col1_w - 4, 1)
    @btn_toggle.render(buffer, x + 4, cur_y + 6, col1_w - 4, 1)
    @btn_danger.render(buffer, x + 4, cur_y + 8, col1_w - 4, 1)

    col2_x = x + 2 + col1_w + 2
    d_card = Opal::UI::Box.new(border: :rounded, title: "Dropdown & Select", border_fg: Opal::Color.cyan)
    d_card.render(buffer, col2_x, cur_y, col1_w, 14)

    buffer.put_string(col2_x + 2, cur_y + 2, "Select Target Deployment:", fg: Opal::Color.white, bold: true)
    @dropdown.render(buffer, col2_x + 2, cur_y + 4, col1_w - 4, 1)

    buffer.put_string(col2_x + 2, cur_y + 7, "Selected Region:", fg: Opal::Color.bright_black)
    buffer.put_string(col2_x + 2, cur_y + 8, @dropdown.selected_item, fg: Opal::Color.yellow, bold: true)
    buffer.put_string(col2_x + 2, cur_y + 10, "Auto-upward flipping near edge.", fg: Opal::Color.bright_black)

    col3_x = col2_x + col1_w + 2
    s_card = Opal::UI::Box.new(border: :rounded, title: "ScrollBars", border_fg: Opal::Color.cyan)
    s_card.render(buffer, col3_x, cur_y, col1_w, 14)

    buffer.put_string(col3_x + 2, cur_y + 2, "Vertical (Drag/Click):", fg: Opal::Color.white)
    @v_scrollbar.render(buffer, col3_x + 2, cur_y + 4, 1, 8)

    buffer.put_string(col3_x + 6, cur_y + 4, "Value: #{@v_scrollbar.value}/#{@v_scrollbar.max_value}", fg: Opal::Color.bright_cyan)
    buffer.put_string(col3_x + 6, cur_y + 6, "Proportional thumb", fg: Opal::Color.bright_black)

    buffer.put_string(col3_x + 2, cur_y + 10, "Horizontal ScrollBar:", fg: Opal::Color.white)
    @h_scrollbar.render(buffer, col3_x + 2, cur_y + 12, col1_w - 4, 1)
  end
end

# -----------------------------------------------------------------------------
# Slide 27: 2D Vector Graphics Primitives (NEW)
# -----------------------------------------------------------------------------
class Primitives2DSlide < ShowcaseSlide
  property time : Float64 = 0.0
  property? animating : Bool = true
  property radius : Int32 = 6

  def title : String
    "2D Vector Graphics Primitives"
  end

  def category : String
    "Graphics & Rendering (New)"
  end

  def hints : String
    "[Space] Pause Animation   [+/-] Adjust Radius"
  end

  def tick : Nil
    @time += 0.06 if @animating
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "space", " "
      @animating = !@animating
      true
    when "+", "="
      @radius = Math.min(14, @radius + 1)
      true
    when "-", "_"
      @radius = Math.max(2, @radius - 1)
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> 2D Graphics Primitives ── Lines, Circles, Rectangles & Triangles", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "Bresenham algorithms with 2:1 character aspect compensation and clip protection.", fg: Opal::Color.bright_black)
    cur_y += 2

    pane_w = (w - 8) // 3
    pane_h = Math.max(12, h - 5)

    p1 = Opal::UI::Box.new(border: :rounded, title: "Lines & Shadows", border_fg: Opal::Color.cyan)
    p1.render(buffer, x + 2, cur_y, pane_w, pane_h)

    cx1 = x + 2 + pane_w // 2
    cy1 = cur_y + 4
    len = 7.0
    lx = (cx1 + Math.cos(@time) * len).round.to_i
    ly = (cy1 + Math.sin(@time) * len * 0.5).round.to_i
    Opal::Graphics::Primitives2D.line(buffer, cx1, cy1, lx, ly, char: '•', fg: Opal::Color.bright_cyan)
    Opal::Graphics::Primitives2D.line(buffer, x + 4, cur_y + 8, x + pane_w - 2, cur_y + 8, style: :dashed, fg: Opal::Color.yellow)
    Opal::Graphics::Primitives2D.rect_with_shadow(buffer, x + 4, cur_y + 10, pane_w - 8, 4, border_fg: Opal::Color.green, title: "Box")

    p2_x = x + 2 + pane_w + 2
    p2 = Opal::UI::Box.new(border: :rounded, title: "Circles & Ellipses", border_fg: Opal::Color.cyan)
    p2.render(buffer, p2_x, cur_y, pane_w, pane_h)

    cx2 = p2_x + pane_w // 2
    cy2 = cur_y + pane_h // 2
    Opal::Graphics::Primitives2D.circle(buffer, cx2, cy2, @radius, char: '○', fg: Opal::Color.magenta)
    Opal::Graphics::Primitives2D.ellipse(buffer, cx2, cy2, @radius + 4, @radius // 2 + 1, char: '·', fg: Opal::Color.bright_black)
    buffer.put_char(cx2, cy2, '+', fg: Opal::Color.bright_white)
    buffer.put_string(p2_x + 2, cur_y + pane_h - 2, "Radius: #{@radius}", fg: Opal::Color.bright_black)

    p3_x = p2_x + pane_w + 2
    p3 = Opal::UI::Box.new(border: :rounded, title: "Filled Polygons", border_fg: Opal::Color.cyan)
    p3.render(buffer, p3_x, cur_y, pane_w, pane_h)

    t_offset = Math.sin(@time * 1.5) * 4.0
    x0 = p3_x + pane_w // 2 + t_offset.round.to_i
    y0 = cur_y + 2
    x1 = p3_x + 4
    y1 = cur_y + pane_h - 3
    x2 = p3_x + pane_w - 4
    y2 = cur_y + pane_h - 3
    Opal::Graphics::Primitives2D.fill_triangle(buffer, x0, y0, x1, y1, x2, y2, char: '▓', fg: Opal::Color.blue)
    Opal::Graphics::Primitives2D.line(buffer, x0, y0, x1, y1, fg: Opal::Color.bright_cyan)
    Opal::Graphics::Primitives2D.line(buffer, x1, y1, x2, y2, fg: Opal::Color.bright_cyan)
    Opal::Graphics::Primitives2D.line(buffer, x2, y2, x0, y0, fg: Opal::Color.bright_cyan)
  end
end

# -----------------------------------------------------------------------------
# Slide 28: 3D Mesh Viewport & Primitives (NEW)
# -----------------------------------------------------------------------------
class Mesh3DSlide < ShowcaseSlide
  getter mesh_view : Opal::UI::Mesh3D

  def initialize
    @mesh_view = Opal::UI::Mesh3D.new(shape: :cube, auto_rotate: true)
  end

  def title : String
    "3D Mesh Viewport & Primitives"
  end

  def category : String
    "3D Graphics Engine (New)"
  end

  def hints : String
    "[Right-Drag] Rotate   [Wheel] Zoom   [1-5] Shape (Cube/Sphere/Cyl/Pyr/Torus)   [Space] Wireframe   [r] Auto-Spin"
  end

  def tick : Nil
    @mesh_view.tick
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @mesh_view.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @mesh_view.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @mesh_view.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 29: Windowing & Multi-Layer Compositing (NEW)
# -----------------------------------------------------------------------------
class WindowingSlide < ShowcaseSlide
  getter window : Opal::UI::Window

  def initialize
    @window = Opal::UI::Window.new(
      title: "Cluster Service Node #07",
      x: 14,
      y: 6,
      width: 48,
      height: 12,
      content: Opal::UI::Text.new("CONTAINER RUNTIME // ACTIVE\n\nPod ID: k8s-mesh-091a\nStatus: 100% Nominal\nIP: 10.244.1.42\nCPU: 24% | Mem: 412 MB\n\nDrag title bar to move.\nDrag borders to resize.", fg: Opal::Color.bright_white)
    )
  end

  def title : String
    "Windowing & Multi-Layer Compositing"
  end

  def category : String
    "Overlays & Layers (New)"
  end

  def hints : String
    "[Drag Title] Move Window   [Drag Borders] Resize   [Click [-]/[^]/[x]] Window Controls"
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @window.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, ">> Multi-Layer Compositing ── Draggable Windows & Buffer Clipping", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "LayerStack isolates transparent buffers across depth tiers with clipping protection.", fg: Opal::Color.bright_black)
    cur_y += 2

    # Draw background content grid (Desktop layer)
    (cur_y...y + h - 1).each do |by|
      (x + 2...x + w - 2).step(14) do |bx|
        buffer.put_string(bx, by, "+---[NODE]---+", fg: Opal::Color.rgb(40, 50, 70), dim: true)
      end
    end

    bg_box = Opal::UI::Box.new(
      child: Opal::UI::Text.new("BACKGROUND SERVICE MESH:\n\nCluster IP: 10.244.0.1\nThroughput: 8.4 Gbps\nStatus: Healthy\nLatency: 1.2ms", fg: Opal::Color.white),
      border: :single,
      border_fg: Opal::Color.bright_black,
      title: "Infrastructure Monitor"
    )
    bg_box.render(buffer, x + 4, cur_y + 1, 38, 10)

    # Render floating Window on top
    @window.render(buffer, 0, 0, w, h)
  end
end

# -----------------------------------------------------------------------------
# Slide 30: Theme Store & WCAG Contrast Studio (NEW)
# -----------------------------------------------------------------------------
class ThemeStoreSlide < ShowcaseSlide
  property theme_index : Int32 = 0
  @theme_names : Array(String)

  def initialize
    @theme_names = Opal.theme_store.names
  end

  def title : String
    "Theme Store & WCAG Contrast Studio"
  end

  def category : String
    "Design System (New)"
  end

  def hints : String
    "[↑/↓] or [←/→] Select Theme Preset   [Space] Next Theme   [r] Reset"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "right", "down", "space", "j", "l"
      @theme_index = (@theme_index + 1) % @theme_names.size
      Opal.theme = @theme_names[@theme_index]
      true
    when "left", "up", "k", "h"
      @theme_index = (@theme_index - 1 + @theme_names.size) % @theme_names.size
      Opal.theme = @theme_names[@theme_index]
      true
    when "r"
      @theme_index = 0
      Opal.theme = @theme_names[0]
      true
    else
      false
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    case event.button
    when Opal::Terminal::MouseButton::WheelUp
      @theme_index = (@theme_index - 1 + @theme_names.size) % @theme_names.size
      Opal.theme = @theme_names[@theme_index]
      true
    when Opal::Terminal::MouseButton::WheelDown
      @theme_index = (@theme_index + 1) % @theme_names.size
      Opal.theme = @theme_names[@theme_index]
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    theme_name = @theme_names[@theme_index]? || @theme_names[0]
    theme = Opal.theme_store.get(theme_name)

    buffer.put_string(x + 2, cur_y, ">> Theme Store Studio ── [Preset #{@theme_index + 1}/#{@theme_names.size}: :#{theme_name}]", fg: theme.primary, bold: true)
    cur_y += 1
    buffer.put_string(x + 2, cur_y, "16 high-fidelity themes with real-time WCAG 2.1 relative luminance and contrast auditing.", fg: theme.text_muted)
    cur_y += 2

    list_w = 24
    list_h = Math.max(12, h - 5)
    l_box = Opal::UI::Box.new(border: :rounded, title: "Theme Presets", border_fg: theme.border, title_fg: theme.primary)
    l_box.render(buffer, x + 2, cur_y, list_w, list_h)

    @theme_names.each_with_index do |name, idx|
      row_y = cur_y + 1 + idx
      break if row_y >= cur_y + list_h - 1
      is_active = (idx == @theme_index)
      prefix = is_active ? "> " : "  "
      str = "#{prefix}:#{name}"
      if is_active
        buffer.put_string(x + 3, row_y, str.ljust(list_w - 2), fg: theme.background, bg: theme.primary, bold: true)
      else
        buffer.put_string(x + 3, row_y, str, fg: theme.text_muted)
      end
    end

    mid_x = x + 2 + list_w + 2
    mid_w = 32
    m_box = Opal::UI::Box.new(border: :rounded, title: "Semantic Swatches", border_fg: theme.border, title_fg: theme.accent)
    m_box.render(buffer, mid_x, cur_y, mid_w, list_h)

    tokens = [
      {"Primary", theme.primary},
      {"Secondary", theme.secondary},
      {"Accent", theme.accent},
      {"Background", theme.background},
      {"Surface", theme.surface},
      {"Text", theme.text},
      {"Muted Text", theme.text_muted},
      {"Border", theme.border},
      {"Success", theme.success},
      {"Warning", theme.warning},
      {"Danger", theme.danger},
      {"Info", theme.info},
    ]

    tokens.each_with_index do |(t_name, t_col), idx|
      swatch_y = cur_y + 1 + idx
      break if swatch_y >= cur_y + list_h - 1
      buffer.put_string(mid_x + 2, swatch_y, "████", fg: t_col)
      buffer.put_string(mid_x + 7, swatch_y, t_name.ljust(11), fg: theme.text, bold: true)
      buffer.put_string(mid_x + 19, swatch_y, t_col.to_hex, fg: theme.text_muted)
    end

    right_x = mid_x + mid_w + 2
    right_w = Math.max(22, w - right_x - 2)
    r_box = Opal::UI::Box.new(border: :rounded, title: "WCAG 2.1 Contrast Audit", border_fg: theme.border, title_fg: theme.success)
    r_box.render(buffer, right_x, cur_y, right_w, list_h)

    ratio_main = theme.text.contrast_ratio(theme.background)
    ratio_muted = theme.text_muted.contrast_ratio(theme.background)
    ratio_pri = theme.primary.contrast_ratio(theme.background)

    audit_row = cur_y + 2
    buffer.put_string(right_x + 2, audit_row, "Text on Background:", fg: theme.text, bold: true)
    audit_row += 1
    badge_main = ratio_main >= 7.0 ? "[AAA 7.0+]" : (ratio_main >= 4.5 ? "[AA 4.5+]" : "[FAIL]")
    badge_col = ratio_main >= 4.5 ? theme.success : theme.danger
    buffer.put_string(right_x + 2, audit_row, "Ratio: #{ratio_main.round(1)}:1  #{badge_main}", fg: badge_col, bold: true)
    audit_row += 2

    buffer.put_string(right_x + 2, audit_row, "Muted on Background:", fg: theme.text_muted)
    audit_row += 1
    badge_muted = ratio_muted >= 4.5 ? "[AA 4.5+]" : (ratio_muted >= 3.0 ? "[AA-Large]" : "[LOW]")
    buffer.put_string(right_x + 2, audit_row, "Ratio: #{ratio_muted.round(1)}:1  #{badge_muted}", fg: theme.text_muted)
    audit_row += 2

    buffer.put_string(right_x + 2, audit_row, "Primary on Background:", fg: theme.primary, bold: true)
    audit_row += 1
    badge_pri = ratio_pri >= 4.5 ? "[AA 4.5+]" : "[FAIL]"
    buffer.put_string(right_x + 2, audit_row, "Ratio: #{ratio_pri.round(1)}:1  #{badge_pri}", fg: theme.primary)
    audit_row += 2

    buffer.put_string(right_x + 2, audit_row, "Readable against BG?", fg: theme.text)
    audit_row += 1
    is_readable = theme.text.readable_against?(theme.background)
    buffer.put_string(right_x + 2, audit_row, is_readable ? "[OK] Accessible & Compliant" : "[!] Contrast Warning", fg: is_readable ? theme.success : theme.warning, bold: true)
    audit_row += 2

    if audit_row < cur_y + list_h - 2
      buffer.put_string(right_x + 2, audit_row, "Borders & Character Swaps:", fg: theme.accent, bold: true)
      audit_row += 1
      buffer.put_string(right_x + 2, audit_row, "Top: #{theme.window_border.top}  Thumb: #{theme.glyphs.scrollbar_thumb}", fg: theme.text_muted)
      audit_row += 1
      buffer.put_string(right_x + 2, audit_row, "Win: #{theme.glyphs.window_close} #{theme.glyphs.window_maximize}  Cursor: #{theme.glyphs.cursor}", fg: theme.text_muted)
    end
  end
end

# -----------------------------------------------------------------------------
# Slide 31: Python Textual-Inspired Architecture (Dock, Grid, Controls & Screen)
# -----------------------------------------------------------------------------
class TextualControlsSlide < ShowcaseSlide
  getter header : Opal::UI::Header
  getter footer : Opal::UI::Footer
  getter switch_sync : Opal::UI::Switch
  getter switch_gpu : Opal::UI::Switch
  getter radio_set : Opal::UI::RadioSet
  getter collapsible : Opal::UI::Collapsible
  getter digits : Opal::UI::Digits
  getter loading_dots : Opal::UI::LoadingIndicator
  getter loading_bars : Opal::UI::LoadingIndicator
  getter placeholder : Opal::UI::Placeholder
  getter rich_log : Opal::UI::RichLog
  property focus_idx : Int32 = 0
  property tick_count : Int32 = 0

  def initialize
    @header = Opal::UI::Header.new(
      title: "OPAL TEXTUAL WORKSPACE",
      subtitle: "Dock / Grid / Screen Engine",
      icon: "[*]",
      show_clock: true
    )

    @switch_sync = Opal::UI::Switch.new(label: "Live Telemetry", on: true)
    @switch_gpu = Opal::UI::Switch.new(label: "Shader GPU Accel", on: true)

    @radio_set = Opal::UI::RadioSet.new([
      "Balanced Mode",
      "High Performance",
      "Battery Saver",
    ], selected_index: 1)

    child_card = Opal::UI::Text.new("Workers: 4 fibers\nEngine: Zero-Alloc\nQueue: 0 pending")
    @collapsible = Opal::UI::Collapsible.new(
      title: "Engine Diagnostics",
      child: child_card,
      collapsed: false
    )

    @digits = Opal::UI::Digits.new("98%", fg: :bright_green)
    @loading_dots = Opal::UI::LoadingIndicator.new(label: "Worker Fiber Active", style: :dots, fg: :bright_cyan)
    @loading_bars = Opal::UI::LoadingIndicator.new(label: "Render Pipeline 60fps", style: :bars, fg: :bright_yellow)
    @placeholder = Opal::UI::Placeholder.new("Sub-Viewport", border: :rounded)

    @rich_log = Opal::UI::RichLog.new(max_lines: 50)
    @rich_log.write("[00:00:00] Textual engine initialized")
    @rich_log.write("[00:00:01] Dock container mounted: left, center, right")
    @rich_log.write("[00:00:02] QueryEngine ready: DOM selectors active")
    @rich_log.write("[00:00:03] Background worker fiber spawned")

    @switch_sync.on_change do |val|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Telemetry switch -> #{val ? "ON" : "OFF"}")
    end

    @switch_gpu.on_change do |val|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] GPU Accel switch -> #{val ? "ENABLED" : "DISABLED"}")
    end

    @radio_set.on_change do |_idx, lbl|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Power Profile -> #{lbl}")
    end

    @collapsible.on_toggle do |col|
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Diagnostics panel -> #{col ? "Collapsed" : "Expanded"}")
    end

    @footer = Opal::UI::Footer.new
    @footer.add("Tab", "Cycle Focus")
    @footer.add("Space", "Toggle")
    @footer.add("1-3", "Profile")
    @footer.add("L", "Push Log")

    update_focus
  end

  def title : String
    "Textual Architecture"
  end

  def category : String
    "Modern Controls & Engine"
  end

  def hints : String
    "[Tab] Cycle Focus  [Space] Toggle  [1-3] Select Mode  [L] Append Log"
  end

  private def focus_controls : Array(Opal::UI::Control)
    [@switch_sync, @switch_gpu, @radio_set, @collapsible, @rich_log]
  end

  private def update_focus : Nil
    controls = focus_controls
    controls.each_with_index do |ctrl, idx|
      ctrl.focused = (idx == @focus_idx)
    end
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "tab"
      @focus_idx = (@focus_idx + 1) % focus_controls.size
      update_focus
      true
    when "l", "L"
      @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] Manual telemetry packet sent")
      true
    when "1"
      @radio_set.select_index(0)
      true
    when "2"
      @radio_set.select_index(1)
      true
    when "3"
      @radio_set.select_index(2)
      true
    else
      ctrl = focus_controls[@focus_idx]?
      if ctrl
        ctrl.handle_key(key)
      else
        false
      end
    end
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    if @switch_sync.handle_mouse(event)
      @focus_idx = 0
      update_focus
      return true
    end
    if @switch_gpu.handle_mouse(event)
      @focus_idx = 1
      update_focus
      return true
    end
    if @radio_set.handle_mouse(event)
      @focus_idx = 2
      update_focus
      return true
    end
    if @collapsible.handle_mouse(event)
      @focus_idx = 3
      update_focus
      return true
    end
    if @rich_log.handle_mouse(event)
      @focus_idx = 4
      update_focus
      return true
    end
    if @footer.handle_mouse(event)
      return true
    end
    false
  end

  def tick : Nil
    @loading_dots.tick
    @loading_bars.tick
    @tick_count += 1

    # Simulate dynamic telemetry update
    if @switch_sync.on?
      if @tick_count % 30 == 0
        cpu_load = 92 + (@tick_count % 8)
        @digits.text = "#{cpu_load}%"
      end

      if @tick_count % 60 == 0
        @rich_log.write("[#{Time.local.to_s("%H:%M:%S")}] [Worker ##{@tick_count // 60}] Heartbeat ping OK (0.4ms)")
      end
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    return if w < 20 || h < 8

    # 1. Render Top Header
    @header.render(buffer, x, y, w, 1)

    # 2. Render Bottom Footer
    @footer.render(buffer, x, y + h - 1, w, 1)

    # 3. Main Workspace Area (between Header and Footer)
    main_y = y + 1
    main_h = Math.max(0, h - 2)
    return if main_h < 4

    col_gap = 1
    left_w = Math.min(28, (w * 0.32).to_i)
    center_w = Math.min(26, (w * 0.30).to_i)
    right_x = x + left_w + col_gap + center_w + col_gap
    right_w = Math.max(16, (x + w) - right_x)

    theme = Opal::Theme.current

    # Left Column: Reactive Controls
    left_x = x
    left_box = Opal::UI::Box.new(border: :rounded, title: "Reactive Controls", border_fg: theme.border, title_fg: theme.primary)
    left_box.render(buffer, left_x, main_y, left_w, main_h)

    ctrl_y = main_y + 1
    @switch_sync.render(buffer, left_x + 2, ctrl_y, left_w - 4, 1)
    ctrl_y += 2
    @switch_gpu.render(buffer, left_x + 2, ctrl_y, left_w - 4, 1)
    ctrl_y += 2

    buffer.put_string(left_x + 2, ctrl_y, "─" * Math.max(0, left_w - 4), fg: theme.border)
    ctrl_y += 1

    buffer.put_string(left_x + 2, ctrl_y, "Power Profile:", fg: theme.accent, bold: true)
    ctrl_y += 1
    @radio_set.render(buffer, left_x + 2, ctrl_y, left_w - 4, 3)
    ctrl_y += 4

    if ctrl_y < main_y + main_h - 2
      buffer.put_string(left_x + 2, ctrl_y, "─" * Math.max(0, left_w - 4), fg: theme.border)
      ctrl_y += 1
      rem_h = Math.max(0, (main_y + main_h - 1) - ctrl_y)
      @collapsible.render(buffer, left_x + 2, ctrl_y, left_w - 4, rem_h)
    end

    # Center Column: Telemetry & Block Digits
    center_x = left_x + left_w + col_gap
    center_box = Opal::UI::Box.new(border: :rounded, title: "Telemetry & Layout", border_fg: theme.border, title_fg: theme.accent)
    center_box.render(buffer, center_x, main_y, center_w, main_h)

    cen_y = main_y + 1
    buffer.put_string(center_x + 2, cen_y, "System Efficiency:", fg: theme.text_muted)
    cen_y += 1
    @digits.render(buffer, center_x + 2, cen_y, center_w - 4, 5)
    cen_y += 6

    @loading_dots.render(buffer, center_x + 2, cen_y, center_w - 4, 1)
    cen_y += 2
    @loading_bars.render(buffer, center_x + 2, cen_y, center_w - 4, 1)
    cen_y += 2

    rem_box_h = Math.max(0, (main_y + main_h - 1) - cen_y)
    if rem_box_h >= 3
      @placeholder.render(buffer, center_x + 2, cen_y, center_w - 4, rem_box_h)
    end

    # Right Column: RichLog Event Stream
    right_box = Opal::UI::Box.new(border: :rounded, title: "Async RichLog Stream", border_fg: theme.border, title_fg: theme.success)
    right_box.render(buffer, right_x, main_y, right_w, main_h)

    @rich_log.render(buffer, right_x + 1, main_y + 1, right_w - 2, Math.max(0, main_h - 2))
  end
end

# -----------------------------------------------------------------------------
# Slide 32: Grand Finale & Conclusion (Markdown Summary)
# -----------------------------------------------------------------------------
class FinaleSlide < ShowcaseSlide
  getter viewer : Opal::UI::MarkdownViewer

  def initialize
    doc = <<-MD
    # [*] You Have Completed the Opal TUI Tour!

    All core capabilities have been showcased:
    - [OK] **Interactive Controls** (Buttons, Dropdowns, ScrollBars)
    - [OK] **Python Textual Architecture** (Dock, Grid, Switches, RadioSets, Collapsibles, Digits, RichLog, Workers)
    - [OK] **Multi-Field Form Wizard** with live inline validation & tab navigation
    - [OK] **Live Keystroke Fuzzy Search & Split Preview**
    - [OK] **Interactive FileDialog / FilePicker** with split preview
    - [OK] **TrueColor 24-Bit ColorPicker** with RGB sliders & palette studio
    - [OK] **2D/3D Rotatable Color Spectrum & Cube/Sphere Picker**
    - [OK] **2D Graphics Primitives** (Lines, Circles, Rectangles, Triangles)
    - [OK] **3D Mesh Viewport & Primitives** (Cube, Sphere, Torus, Cylinder, Pyramid)
    - [OK] **Windowing & Multi-Layer Compositing** (Floating windows, layers, clipping)
    - [OK] **Theme Store & Contrast Studio** (16 presets, WCAG 2.1 compliance)
    - [OK] **Image to ASCII Art Engine** with half-block & nearest-char luminance modes
    - [OK] **Text Shader Engine & Compositing FX** with 13 procedural shaders
    - [OK] **Cluster Data Visualizations** (Sparklines, BarCharts, PieCharts, LineGraphs, Gauges, Trees)
    - [OK] **Zebra Data Tables & Scrollable Viewports**
    - [OK] **CodeView Syntax Highlighter & Hex Binary Inspector**
    - [OK] **Double-Buffered Split Views & Theme Engine**
    - [OK] **Modals, Toasts, Command Palette & Autocomplete**
    - [OK] **OSC 8 Hyperlinks & OSC 52 Desktop Clipboard**
    - [OK] **The Elm Architecture (TEA) Reactive Engine**

    ### >> Getting Started
    Add Opal to your `shard.yml`:
    ```yaml
    dependencies:
      opal:
        github: sol-vin/opal
        version: ~> 0.1.0
    ```

    *Thank you for exploring Opal! Press **[ESC]** to exit.*
    MD

    @viewer = Opal::UI::MarkdownViewer.new(doc, width: 80)
  end

  def title : String
    "Grand Finale & Resources"
  end

  def category : String
    "Tour Complete"
  end

  def hints : String
    "[PageUp/Down] Scroll Markdown Summary"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @viewer.handle_key(key)
  end

  def handle_mouse(event : Opal::Terminal::MouseEvent) : Bool
    @viewer.handle_mouse(event)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @viewer.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# =============================================================================
# Main Elm Architecture Presentation Runner
# =============================================================================
class ShowcaseAppModel
  include Opal::TEA::Model

  getter slides : Array(ShowcaseSlide)
  property current_idx : Int32 = 0

  def initialize
    @slides = [
      WelcomeSlide.new,
      FormWizardSlide.new,
      FormCodeSlide.new,
      FuzzyFinderSlide.new,
      FileDialogSlide.new,
      FileDialogCodeSlide.new,
      ColorPickerSlide.new,
      ColorPickerCodeSlide.new,
      DatavizSlide.new,
      PieChartSlide.new,
      LineGraphSlide.new,
      TablesSlide.new,
      DevToolsSlide.new,
      LayoutsSlide.new,
      TabsSlide.new,
      ModalsSlide.new,
      ToastsSlide.new,
      CommandPaletteSlide.new,
      AutocompleteSlide.new,
      ThemesSlide.new,
      TerminalOscSlide.new,
      TeaEngineSlide.new,
      TextShaderSlide.new,
      ColorPicker3DSlide.new,
      AsciiImageSlide.new,
      ControlsSlide.new,
      Primitives2DSlide.new,
      Mesh3DSlide.new,
      WindowingSlide.new,
      ThemeStoreSlide.new,
      TextualControlsSlide.new,
      FinaleSlide.new,
    ]
  end

  def init : Opal::TEA::Cmd
    schedule_tick
  end

  def update(msg : Opal::TEA::Msg) : {Opal::TEA::Model, Opal::TEA::Cmd}
    case msg
    when Opal::TEA::TickMsg
      @slides[@current_idx].tick
      {self, schedule_tick}
    when Opal::TEA::KeyMsg
      # 1. Global Slide Navigation
      # Shift+Right: advance to next slide
      if msg.matches?("shift+right")
        @current_idx = (@current_idx + 1) % @slides.size
        return {self, Opal::TEA::Cmd.redraw}
      end

      # Shift+Left: return to previous slide
      if msg.matches?("shift+left")
        @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
        return {self, Opal::TEA::Cmd.redraw}
      end

      # Quit command: ESC or Ctrl+C
      if msg.matches?("escape") || msg.matches?("esc") || msg.matches?("ctrl+c")
        return {self, Opal::TEA::Cmd.quit}
      end

      # 2. Forward Key to Active Slide (Left, Right, numbers, etc. are passed directly)
      ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
      @slides[@current_idx].handle_key(ev)
      {self, Opal::TEA::Cmd.none}
    when Opal::TEA::MouseMsg
      cols, rows = Opal::Terminal.default_driver.size

      # 1. Global Navigation via Mouse Click:
      if msg.left_click?
        # Header click (rows 1 or 2):
        if msg.y <= 2
          if msg.x > cols // 2
            @current_idx = (@current_idx + 1) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          else
            @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          end
        end

        # Footer click (bottom row):
        # Footer text: " [Shift+→] Next  [Shift+←] Prev  [ESC] Quit │ ..."
        if msg.y >= rows - 1
          if msg.x >= 1 && msg.x <= 16
            @current_idx = (@current_idx + 1) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          elsif msg.x >= 17 && msg.x <= 32
            @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
            return {self, Opal::TEA::Cmd.redraw}
          elsif msg.x >= 33 && msg.x <= 44
            return {self, Opal::TEA::Cmd.quit}
          end
        end
      end

      # 2. Forward Mouse Event to Active Slide
      ev = Opal::Terminal::MouseEvent.new(
        x: msg.x,
        y: msg.y,
        button: msg.button,
        action: msg.action,
        ctrl: msg.ctrl?,
        alt: msg.alt?,
        shift: msg.shift?
      )
      @slides[@current_idx].handle_mouse(ev)
      {self, Opal::TEA::Cmd.none}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def render(buffer : Opal::UI::Buffer) : Nil
    cols = buffer.width
    rows = buffer.height
    return if cols < 10 || rows < 5

    active = @slides[@current_idx]

    # Explicitly clear/fill entire canvas area with spaces to ensure zero dirty cells
    buffer.fill(0, 0, cols, rows, ' ')

    # Top Header Banner
    header_text = " [*] OPAL TUI SHOWCASE ── Slide #{@current_idx + 1}/#{@slides.size}: [#{active.title}] ── [#{active.category}]"
    buffer.put_string(0, 0, header_text, fg: Opal::Color.bright_cyan, bold: true, max_width: cols)
    buffer.put_string(0, 1, "─" * cols, fg: Opal::Color.bright_black, max_width: cols)

    # Active Slide Canvas
    slide_h = Math.max(0, rows - 4)
    active.render(buffer, 0, 2, cols, slide_h) if slide_h > 0

    # Bottom Footer
    if rows >= 4
      buffer.put_string(0, rows - 2, "─" * cols, fg: Opal::Color.bright_black, max_width: cols)
      footer_text = " [Shift+→] Next  [Shift+←] Prev  [ESC] Quit │ #{active.hints}"
      buffer.put_string(0, rows - 1, footer_text, fg: Opal::Color.bright_white, max_width: cols)
    end
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 140)
    rows = rows.clamp(22, 45)

    buffer = Opal::UI::Buffer.new(cols, rows)
    render(buffer)
    buffer.render_to_string(with_ansi: true)
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(50.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

# Launch demo application if run directly
if PROGRAM_NAME.includes?("10_opal_tui_showcase") || PROGRAM_NAME.ends_with?("opal-demo")
  puts "Launching Opal TUI Showcase..."
  Opal.run_tea(ShowcaseAppModel.new, alt_screen: true, diff_render: true)
  puts "Opal TUI Showcase terminated cleanly. Terminal restored."
end
