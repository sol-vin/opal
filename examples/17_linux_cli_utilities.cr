require "../src/opal"
require "../src/opal/cli/main"

# Example 17: Linux CLI Utilities Showcase & Programmatic API
# Demonstrates how Opal's Unix-style print mode utilities can be invoked
# both via the CLI toolchain and programmatically in Crystal scripts.

puts Opal.style.bold.fg(:magenta).render("=== OPAL LINUX CLI UTILITIES & PRINT MODE DEMO ===")
puts

# 1. Styled Table (Print Mode)
puts Opal.style.bold.fg(:cyan).render("1. Print Mode Table (CSV / TSV / JSON formatting):")
headers = ["Container", "Image", "Status", "Ports", "CPU %"]
rows = [
  ["web-gateway", "nginx:alpine", "Up 4 hours", "0.0.0.0:80->80", "1.2%"],
  ["auth-service", "opal/auth:1.2", "Up 12 days", "8080/tcp", "0.4%"],
  ["redis-cache", "redis:7-alpine", "Up 12 days", "6379/tcp", "2.8%"],
  ["postgres-db", "postgres:16", "Up 12 days", "5432/tcp", "8.5%"],
]

Opal::UI::Table.print(headers, rows, zebra: true, border_style: :rounded)
puts

# 2. Horizontal Bar Chart (Print Mode)
puts Opal.style.bold.fg(:cyan).render("2. Print Mode Bar Chart:")
bar_items = [
  Opal::UI::BarItem.new("Frontend (React/TS)", 45.0, :cyan),
  Opal::UI::BarItem.new("Core API (Crystal)", 92.0, :green),
  Opal::UI::BarItem.new("Workers (Go)", 68.0, :yellow),
  Opal::UI::BarItem.new("Analytics (Python)", 34.0, :magenta),
]
Opal::UI::BarChart.print(bar_items, title: "Resource Utilization Index")
puts

# 3. Block Sparkline (Print Mode)
puts Opal.style.bold.fg(:cyan).render("3. Print Mode Sparkline:")
spark_data = [12.0, 15.0, 22.0, 35.0, 58.0, 72.0, 89.0, 95.0, 100.0, 82.0, 60.0, 30.0, 18.0]
Opal::UI::Sparkline.print(spark_data, title: "CPU Activity (Last 60s)", color: :green)
puts

# 4. Progress Gauge (Print Mode)
puts Opal.style.bold.fg(:cyan).render("4. Print Mode Progress Gauge:")
Opal::UI::Gauge.print(0.84, label: "Database Migration [840 / 1000]", width: 60)
puts

# 5. Box Framing (Print Mode)
puts Opal.style.bold.fg(:cyan).render("5. Print Mode Terminal Box:")
Opal::UI::Box.print(
  "Environment: production-us-east\nNodes: 32 active | 0 degraded\nThroughput: 42,150 req/sec\nLatency (p99): 4.2ms",
  title: "Cluster Telemetry",
  border: :rounded,
  border_fg: Opal::Color.green
)
puts

# 6. Pill Badges and Divider Rules
puts Opal.style.bold.fg(:cyan).render("6. Styled Badges and Divider Rules:")
Opal::UI::Rule.print("Release Checklist", char: '═', fg: :cyan)
print "Build Status: "
Opal::UI::Badge.print("CI: PASSING", bg: :green, fg: :white)
print " Security Audit: "
Opal::UI::Badge.print("VULNERABILITIES: 0", bg: :blue, fg: :white)
puts
puts

# 7. Markdown Rendering
puts Opal.style.bold.fg(:cyan).render("7. Terminal Markdown Rendering:")
md_sample = <<-MD
### Opal Toolchain Overview
Opal unifies **The Elm Architecture** with rich declarative layout and Linux CLI composition:
* **Pipes First**: Seamlessly compose `cat | opal table` or `curl | opal barchart`
* **Zero Alt-Screen Flicker**: One-shot print mode for continuous shell scripting
* **Auto Detection**: Recognizes CSV, TSV, JSON, Markdown, and words automatically
MD
Opal.print_markdown(md_sample)
puts

puts Opal.style.bold.fg(:green).render("✔ All Linux print utilities demonstrated successfully!")
