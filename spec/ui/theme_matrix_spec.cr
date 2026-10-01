require "../spec_helper"

module Opal
  macro test_theme(theme_name, theme_key)
    describe "Theme: {{theme_name.id}} ({{theme_key}})" do
        it "retrieves and sets {{theme_key}} cleanly" do
          orig = Theme.current
          t = Theme.get({{theme_key}})
          t.name.should_not be_empty
          Theme.current = {{theme_key}}
          Theme.current.name.should eq(t.name)
          Theme.current = orig
        end

        it "has valid color properties with non-zero RGB components" do
          t = Theme.get({{theme_key}})
          t.primary.should_not eq(Color.none)
          t.background.should_not eq(Color.none)
          t.text.should_not eq(Color.none)
          t.surface.should_not eq(Color.none)
          t.border.should_not eq(Color.none)
        end

        it "generates compliant or measurable WCAG contrast audit" do
          t = Theme.get({{theme_key}})
          audit = t.audit_contrast
          audit.has_key?("text_on_background").should be_true
          audit.has_key?("text_on_surface").should be_true
          audit["text_on_background"][:ratio].should be > 1.0
        end

        it "renders UI components with theme styling without crash" do
          orig = Theme.current
          Theme.current = {{theme_key}}
          rendered = Opal.render_ui(width: 60, height: 12) do |ui|
            ui.box(title: "{{theme_name.id}} Showcase", border: Theme.current.box_border) do |b|
              b.vstack(spacing: 1) do |v|
                v.text "Testing theme rendering"
                v.badge "THEMED", :primary
                v.gauge(ratio: 0.75, label: "Ratio")
              end
            end
          end
          rendered.should contain("{{theme_name.id}} Showcase")
          rendered.should contain("Testing theme rendering")
          Theme.current = orig
        end

        it "supports deriving customized variants with overrides" do
          t = Theme.get({{theme_key}})
          custom = t.derive(
            name: "custom_{{theme_key}}",
            primary: Color.hex("#FF00AA"),
            background: Color.hex("#111111")
          )
          custom.name.should eq("custom_{{theme_key}}")
          custom.primary.to_hex.should eq("#FF00AA")
          custom.background.to_hex.should eq("#111111")
        end
      end
    end

  test_theme("Catppuccin Mocha", :catppuccin_mocha)
  test_theme("Catppuccin Latte", :catppuccin_latte)
  test_theme("Dracula", :dracula)
  test_theme("Nord", :nord)
  test_theme("Monokai", :monokai)
  test_theme("Tokyo Night", :tokyo_night)
  test_theme("Gruvbox", :gruvbox)
  test_theme("Solarized Dark", :solarized_dark)
  test_theme("High Contrast", :high_contrast)
  test_theme("Cyberpunk", :cyberpunk)
end
