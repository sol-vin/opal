require "../src/opal"

# Showcases Opal's data visualization widgets: Sparkline, BarChart, Gauge, Tree, and Theme switching.
Opal.theme = :catppuccin_mocha
theme = Opal.theme

cpu_history = [12.0, 15.4, 22.0, 45.2, 78.0, 85.5, 92.0, 64.0, 48.2, 35.0, 24.1, 18.0]

ui = Opal::UI.render(width: 75, height: 28) do |ui|
  ui.box border: :rounded, border_fg: theme.primary, title: "💎 Opal Cluster Analytics", title_fg: theme.accent do |card|
    card.vstack(spacing: 1) do |vs|
      vs.hstack do |hs|
        hs.box(border: :single, border_fg: theme.border, padding: 1, title: "CPU Load Trend") do |b|
          b.vstack do |v|
            v.text("Realtime Load:")
            v.sparkline(cpu_history, color: theme.secondary)
            v.gauge(0.68, label: "Current: 68%", color: theme.warning)
          end
        end

        hs.box(border: :single, border_fg: theme.border, padding: 1, title: "Memory Allocation (MB)") do |b|
          b.barchart do |bc|
            bc.bar("API Worker", 420, color: theme.success)
            bc.bar("DB Pool", 850, color: theme.secondary)
            bc.bar("Cache Node", 230, color: theme.info)
            bc.bar("Background", 1120, color: theme.danger)
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

puts ui
