require "../src/opal"

# =============================================================================
# 💎 OPAL FULL-FEATURED TUI SHOWCASE & INTERACTIVE DEMO APP
# =============================================================================
# A complete, linear 21-scene interactive presentation demonstrating all
# capabilities of the Opal framework.
#
# Navigation:
#   [ESC] or [→] or [n] : Advance to Next Slide
#   [←] or [p]          : Return to Previous Slide
#   [q] or [Ctrl+C]     : Exit Demo
#   (Interactive controls for each slide are displayed in the footer)
# =============================================================================

abstract class ShowcaseSlide
  abstract def title : String
  abstract def category : String
  abstract def hints : String

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
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
  def title : String
    "Welcome to Opal"
  end

  def category : String
    "Overview & Markdown"
  end

  def hints : String
    "[ESC / →] Next Slide   [q] Quit Demo"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    doc = <<-MD
    # 💎 Welcome to Opal TUI Framework

    **Next-Generation Terminal User Interface & CLI DSL for Crystal**

    Opal unifies the best terminal engineering paradigms into a cohesive framework:
    - 🍵 **The Elm Architecture (TEA)** — Pure, predictable state transitions (Bubbletea style).
    - 🎨 **Declarative Fluent Styling & Themes** — Lipgloss-inspired styling, 24-bit TrueColor, visual width calculation.
    - ⚡ **Flicker-Free Delta Rendering** — Blessed-inspired double buffering for 60fps smooth updates.
    - 📁 **Rich Interactive Components** — Multi-field forms, live fuzzy search, file dialogs, and color pickers.
    - 📊 **Terminal Data Visualizations** — Sparklines, bar charts, percentage gauges, and trees.

    > *"Build world-class command-line interfaces with zero external C dependencies."*

    ### 🧭 Presentation Navigation Controls
    - **Press `[ESC]` or `[→]` / `[n]`** at any time to advance to the next slide.
    - **Press `[←]` or `[p]`** to navigate back to the previous slide.
    - **Press `[q]`** to exit this tour and return to your shell.
    MD

    md_el = Opal::UI::MarkdownElement.new(doc, width: w - 4)
    md_el.render(buffer, x + 2, y + 1, w - 4, h - 2)
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
    "[Tab/Shift+Tab] Move Field   [Space] Toggle/Select   [Enter] Validate   [ESC] Next Slide"
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

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    form_w = Math.min(w - 4, 66)
    form_h = Math.min(h - 2, 17)
    @form.render(buffer, x + 2, y + 1, form_w, form_h)

    # Show validation feedback badge
    stat_y = y + form_h + 1
    if stat_y < y + h
      if @submitted
        buffer.put_string(x + 4, stat_y, "✔ Form Validated & Ready for Deployment!", fg: Opal::Color.green, bold: true)
      else
        buffer.put_string(x + 4, stat_y, "ℹ Edit fields with Tab/Space. Press [Enter] to validate.", fg: Opal::Color.cyan)
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
    "[ESC / →] Next Slide   [←] Prev Slide"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "📝 Why Multi-Field Forms Matter", fg: Opal::Color.cyan, bold: true)
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

    @filter_list = Opal::UI::FilterList.new(items: items, title: "🔍 Microservice Search (Fuzzy Filter)", preview_fn: preview)
  end

  def title : String
    "Live Fuzzy Search & Filter"
  end

  def category : String
    "Interactive Search"
  end

  def hints : String
    "[Type] Filter query   [↑/↓] Select   [Backspace] Delete   [ESC] Next Slide"
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
    "[↑/↓] Navigate   [Enter] Enter Folder / Select   [Backspace/←] Up   [Type] Filter   [ESC] Next"
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
    "[ESC / →] Next Slide   [←] Prev Slide"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "📁 Opal::UI::FileDialog & FilePicker DSL", fg: Opal::Color.cyan, bold: true)
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
    "[Tab] Channel   [←/→] Adjust Value   [+/-] Step 1   [1-9] Presets   [ESC] Next Slide"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @picker.handle_key(key)
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
    "[ESC / →] Next Slide   [←] Prev Slide"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "🎨 24-Bit TrueColor & Color Interpolation", fg: Opal::Color.cyan, bold: true)
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
    "[Live Ticking Animation]   [ESC / →] Next Slide"
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

    buffer.put_string(x + 2, cur_y, "📊 Real-Time Cluster Telemetry Dashboard", fg: Opal::Color.cyan, bold: true)
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
    tr.add("Opal Ingress Controller", Opal::Color.cyan, "🌐") do |ingress|
      ingress.add("Authentication Node", Opal::Color.green, "🔒")
      ingress.add("Search & Index Cluster", Opal::Color.yellow, "🔍") do |search|
        search.add("Shard Alpha (Active)", Opal::Color.bright_black, "📦")
        search.add("Shard Beta (Replica)", Opal::Color.bright_black, "📦")
      end
    end
    tr.render(buffer, x + 2, cur_y, w - 4, Math.max(3, (y + h - 1) - cur_y))
  end
end

# -----------------------------------------------------------------------------
# Slide 10: Formatted Data Tables & Viewport (Interactive App)
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
    "[↑/↓] Select Row / Scroll   [Tab] Switch Table/Logs   [ESC] Next Slide"
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

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "📋 Fleet Service Table (#{(@active_pane == :table ? "FOCUS" : "")})", fg: Opal::Color.cyan, bold: true)
    @table.render(buffer, x + 2, y + 3, w - 4, 8)

    vp_y = y + 12
    if vp_y < y + h - 2
      buffer.put_string(x + 2, vp_y, "📜 Live Audit Stream (#{(@active_pane == :viewport ? "FOCUS" : "")})", fg: Opal::Color.cyan, bold: true)
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
    "[↑/↓] Scroll Code & Hex   [ESC / →] Next Slide"
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

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    half_w = (w - 6) // 2

    # Left: CodeView
    buffer.put_string(x + 2, y + 1, "💎 Syntax Highlighted CodeView", fg: Opal::Color.cyan, bold: true)
    @code_view.render(buffer, x + 2, y + 3, half_w, h - 5)

    # Right: HexViewer
    divider_x = x + 2 + half_w
    (y + 1...y + h - 2).each do |div_y|
      buffer.put_char(divider_x, div_y, '│', fg: Opal::Color.bright_black)
    end

    hex_x = divider_x + 2
    buffer.put_string(hex_x, y + 1, "🔍 Binary Memory Dump (HexViewer)", fg: Opal::Color.cyan, bold: true)
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
    "[←/→] Adjust Split Ratio   [ESC / →] Next Slide"
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

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, "📐 Double-Buffered Split Layouts (Ratio: #{(@ratio * 100).to_i}%)", fg: Opal::Color.cyan, bold: true)
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
    "[←/→] or [1-5] Switch Tabs   [ESC / →] Next Slide"
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

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "🗂️ Interactive Tabbed Navigation", fg: Opal::Color.cyan, bold: true)
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
    "[←/→] Select Dialog Button   [ESC / →] Next Slide"
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
    "[1] Info  [2] Success  [3] Warning  [4] Error  [c] Clear  [ESC] Next Slide"
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
    buffer.put_string(x + 2, y + 1, "🍞 Floating Toast Notifications Stack", fg: Opal::Color.cyan, bold: true)
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
    "[Type] Search   [↑/↓] Select   [Enter] Execute   [ESC] Next Slide"
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
    buffer.put_string(x + 2, y + 1, "⚡ Spotlight Command Palette", fg: Opal::Color.cyan, bold: true)
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
    "[Type] Input   [Tab / →] Accept Ghost Completion   [Backspace] Delete   [ESC] Next Slide"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @input.handle_key(key)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    buffer.put_string(x + 2, cur_y, "🔮 Fish/Zsh-Style Inline Ghost-Text Autocomplete", fg: Opal::Color.cyan, bold: true)
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
    "[Space] Cycle Themes   [ESC / →] Next Slide"
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

    buffer.put_string(x + 2, y + 1, "🎨 Active Palette: :#{current_name} (Press Space to Switch)", fg: theme.primary, bold: true)
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
    "[c] Copy to System Clipboard (OSC 52)   [ESC / →] Next Slide"
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "c"
      Opal.copy_to_clipboard("OPAL_SECRET_TOKEN_993478a")
      @copied_status = "✔ Copied 'OPAL_SECRET_TOKEN_993478a' to OS desktop clipboard via OSC 52!"
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    buffer.put_string(x + 2, y + 1, "🖥️ Terminal Environment & Hardware Query", fg: Opal::Color.cyan, bold: true)

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

    buffer.put_string(x + 2, cur_y, "🔗 Clickable Terminal Hyperlinks (OSC 8):", fg: Opal::Color.cyan, bold: true)
    cur_y += 1
    buffer.put_string(x + 4, cur_y, Opal.hyperlink("Open GitHub Repository", "https://github.com/sol-vin/opal"), fg: Opal::Color.bright_cyan, underline: true)
    cur_y += 2

    buffer.put_string(x + 2, cur_y, "📋 Desktop Clipboard Integration (OSC 52):", fg: Opal::Color.cyan, bold: true)
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
    "[+/-] Count   [Space] Pause Auto-Tick   [r] Reset   [ESC] Next Slide"
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
    when "space"
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
    buffer.put_string(x + 2, y + 1, "🍵 Pure Elm Architecture (Model -> Update -> View)", fg: Opal::Color.cyan, bold: true)
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

  def title : String
    "Text Shader Engine & Compositing FX"
  end

  def category : String
    "Post-Processing Engine (New)"
  end

  def hints : String
    "[1] Matrix  [2] CRT  [3] Plasma  [4] Glitch  [5] Fire  [6] Composite  [Space] Pause  [ESC] Next"
  end

  def tick : Nil
    if @animating
      @time += 0.05
      @frame += 1_u64
    end
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    case key.name
    when "1"
      @mode = 1
      true
    when "2"
      @mode = 2
      true
    when "3"
      @mode = 3
      true
    when "4"
      @mode = 4
      true
    when "5"
      @mode = 5
      true
    when "6"
      @mode = 6
      true
    when "space"
      @animating = !@animating
      true
    else
      false
    end
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    cur_y = y + 1
    mode_name = case @mode
                when 1 then "Matrix Digital Rain"
                when 2 then "Retro CRT Scanlines & Glow"
                when 3 then "24-bit TrueColor Sine Wave Plasma"
                when 4 then "Cyberpunk Glitch & Raster Tearing"
                when 5 then "Ascending Fire Dispersion"
                when 6 then "Multi-Layer Composite (Matrix + CRT + Vignette)"
                else        "Custom Shader"
                end

    buffer.put_string(x + 2, cur_y, "🔮 Text Shader Subsystem ── Mode [#{@mode}]: #{mode_name}", fg: Opal::Color.cyan, bold: true)
    cur_y += 2

    # Draw host UI card to be shaded
    card_w = Math.min(w - 4, 68)
    card_h = Math.min(h - 8, 12)
    b = Opal::UI::Box.new(
      child: Opal::UI::Text.new(
        "CYBERNETIC TELEMETRY NODE // ACTIVE\n\n" \
        "Neural Gateway : Synchronized (10 Gbps TrueColor)\n" \
        "Core Flux      : 99.2% Nominal\n" \
        "Buffer Frame   : ##{@frame} | Time: #{@time.round(2)}s\n\n" \
        "Press [1-6] to toggle live procedural shader overlays!",
        fg: Opal::Color.bright_white
      ),
      border: :rounded,
      border_fg: Opal::Color.cyan,
      title: "Core Telemetry"
    )
    b.render(buffer, x + 2, cur_y, card_w, card_h)

    # Apply selected shader pass over the buffer
    case @mode
    when 1
      pass = Opal::Shader::MatrixPass.new(speed: 1.2, density: 0.25)
      pass.apply(buffer, buffer, @time, @frame)
    when 2
      pass = Opal::Shader::CrtPass.new(intensity: 0.45, scanline_gap: 2, phosphor_tint: Opal::Color.green)
      pass.apply(buffer, buffer, @time, @frame)
    when 3
      plasma_region = Opal::Shader::Rect.new(x + 2, cur_y + card_h, card_w, (y + h - 1) - (cur_y + card_h))
      pass = Opal::Shader::PlasmaPass.new(region: plasma_region, scale: 0.2, speed: 1.6)
      pass.apply(buffer, buffer, @time, @frame)
    when 4
      pass = Opal::Shader::GlitchPass.new(intensity: 0.25, slice_height: 3)
      pass.apply(buffer, buffer, @time, @frame)
    when 5
      fire_region = Opal::Shader::Rect.new(x + 2, cur_y + card_h, card_w, (y + h - 1) - (cur_y + card_h))
      pass = Opal::Shader::FirePass.new(region: fire_region, speed: 1.2)
      pass.apply(buffer, buffer, @time, @frame)
    when 6
      pipeline = Opal.shader_pipeline do |p|
        p.matrix(speed: 1.0, density: 0.15)
        p.crt(intensity: 0.35, scanline_gap: 2)
        p.vignette(radius: 0.85, falloff: 0.4)
      end
      pipeline.apply(buffer, @time, @frame)
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
    "[W/A/S/D] Turn 3D Cube   [↑/↓/←/→] Raycast Cursor   [M] Shape   [Space] Auto-Spin   [ESC] Next"
  end

  def tick : Nil
    @picker.tick(0.04)
  end

  def handle_key(key : Opal::Terminal::KeyEvent) : Bool
    @picker.handle_key(key)
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    @picker.render(buffer, x + 2, y + 1, w - 4, h - 2)
  end
end

# -----------------------------------------------------------------------------
# Slide 23: Grand Finale & Conclusion (Markdown Summary)
# -----------------------------------------------------------------------------
class FinaleSlide < ShowcaseSlide
  def title : String
    "Grand Finale & Resources"
  end

  def category : String
    "Tour Complete"
  end

  def hints : String
    "[q / Ctrl+C] Exit Demo   [←] Previous Slides   [ESC] Wrap around to start"
  end

  def render(buffer : Opal::UI::Buffer, x : Int32, y : Int32, w : Int32, h : Int32) : Nil
    doc = <<-MD
    # 💎 You Have Completed the Opal TUI Tour!

    All core capabilities have been showcased:
    - ✔ **Multi-Field Form Wizard** with live inline validation & tab navigation
    - ✔ **Live Keystroke Fuzzy Search & Split Preview**
    - ✔ **Interactive FileDialog / FilePicker** with icons & split preview
    - ✔ **TrueColor 24-Bit ColorPicker** with RGB sliders & palette studio
    - ✔ **2D/3D Rotatable Color Spectrum & Cube/Sphere Picker**
    - ✔ **Text Shader Engine & Multi-Layer Compositing FX**
    - ✔ **Cluster Data Visualizations** (Sparklines, BarCharts, Gauges, Trees)
    - ✔ **Zebra Data Tables & Scrollable Viewports**
    - ✔ **CodeView Syntax Highlighter & Hex Binary Inspector**
    - ✔ **Double-Buffered Split Views & Theme Engine**
    - ✔ **Modals, Toasts, Command Palette & Autocomplete**
    - ✔ **OSC 8 Hyperlinks & OSC 52 Desktop Clipboard**
    - ✔ **The Elm Architecture (TEA) Reactive Engine**

    ### 🚀 Getting Started
    Add Opal to your `shard.yml`:
    ```yaml
    dependencies:
      opal:
        github: sol-vin/opal
        version: ~> 0.1.0
    ```

    *Thank you for exploring Opal! Press **[q]** to exit.*
    MD

    md_el = Opal::UI::MarkdownElement.new(doc, width: w - 4)
    md_el.render(buffer, x + 2, y + 1, w - 4, h - 2)
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
      # Primary requested navigation: ESC key immediately moves to next slide!
      # 'n' and 'pagedown' also reliably advance.
      if msg.matches?("escape") || msg.matches?("esc") || msg.matches?("pagedown") || msg.matches?("n")
        @current_idx = (@current_idx + 1) % @slides.size
        return {self, Opal::TEA::Cmd.none}
      end

      # Dedicated backward navigation: 'p' or PageUp always return
      if msg.matches?("pageup") || msg.matches?("p")
        @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
        return {self, Opal::TEA::Cmd.none}
      end

      # Alternative forward navigation: Right arrow (if not consumed by active input)
      if msg.matches?("right")
        ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
        if !@slides[@current_idx].handle_key(ev)
          @current_idx = (@current_idx + 1) % @slides.size
        end
        return {self, Opal::TEA::Cmd.none}
      end

      # Alternative backward navigation: Left arrow (if not consumed by active input)
      if msg.matches?("left")
        ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
        if !@slides[@current_idx].handle_key(ev)
          @current_idx = (@current_idx - 1 + @slides.size) % @slides.size
        end
        return {self, Opal::TEA::Cmd.none}
      end

      # Quit command: 'q' or 'ctrl+c'
      if msg.matches?("ctrl+c") || msg.matches?("q")
        return {self, Opal::TEA::Cmd.quit}
      end

      # 2. Forward Key to Active Slide
      ev = Opal::Terminal::KeyEvent.new(msg.key, msg.char, msg.ctrl?, msg.alt?, msg.shift?)
      @slides[@current_idx].handle_key(ev)
      {self, Opal::TEA::Cmd.none}
    else
      {self, Opal::TEA::Cmd.none}
    end
  end

  def render(buffer : Opal::UI::Buffer) : Nil
    cols = buffer.width
    rows = buffer.height
    active = @slides[@current_idx]

    # Top Header Banner
    header_text = " 💎 OPAL TUI SHOWCASE ── Slide #{@current_idx + 1}/#{@slides.size}: [#{active.title}] ── [#{active.category}]"
    buffer.put_string(0, 0, header_text, fg: Opal::Color.bright_cyan, bold: true)
    buffer.put_string(0, 1, "─" * cols, fg: Opal::Color.bright_black)

    # Active Slide Canvas
    active.render(buffer, 0, 2, cols, rows - 4)

    # Bottom Footer
    buffer.put_string(0, rows - 2, "─" * cols, fg: Opal::Color.bright_black)
    footer_text = " [ESC / → / n] Next  [← / p] Prev  [q] Quit │ #{active.hints}"
    buffer.put_string(0, rows - 1, footer_text, fg: Opal::Color.bright_white)
  end

  def view : String
    cols, rows = Opal::Terminal.default_driver.size
    cols = cols.clamp(70, 140)
    rows = rows.clamp(22, 45)

    buffer = Opal::UI::Buffer.new(cols, rows)
    render(buffer)
    buffer.to_s
  end

  private def schedule_tick : Opal::TEA::Cmd
    Opal::TEA::Cmd.tick(300.milliseconds) do |_time|
      Opal::TEA::TickMsg.new
    end
  end
end

# Launch demo application if run directly
if PROGRAM_NAME.includes?("10_opal_tui_showcase") || PROGRAM_NAME.ends_with?("opal-demo")
  puts "Launching Opal TUI Showcase..."
  Opal.run_tea(ShowcaseAppModel.new, alt_screen: true)
  puts "Opal TUI Showcase terminated cleanly. Terminal restored."
end
