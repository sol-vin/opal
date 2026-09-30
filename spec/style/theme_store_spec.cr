require "../spec_helper"

describe "Opal::ThemeStore & WCAG Contrast" do
  describe "ThemeStore Presets & Retrieval" do
    it "contains at least 16 registered presets" do
      Opal::ThemeStore.names.size.should be >= 16
      Opal::ThemeStore.has?("catppuccin_mocha").should be_true
      Opal::ThemeStore.has?("cyberpunk").should be_true
      Opal::ThemeStore.has?("synthwave").should be_true
      Opal::ThemeStore.has?("matrix").should be_true
      Opal::ThemeStore.has?("retro_amber").should be_true
      Opal::ThemeStore.has?("one_dark").should be_true
      Opal::ThemeStore.has?("rose_pine").should be_true
    end

    it "retrieves theme by string or symbol" do
      t1 = Opal::ThemeStore.get("dracula")
      t2 = Opal::ThemeStore.get(:dracula)
      t1.name.should eq("dracula")
      t2.name.should eq("dracula")
    end

    it "falls back gracefully on unknown theme name" do
      fallback = Opal::ThemeStore.get("nonexistent_theme_name")
      fallback.should_not be_nil
    end

    it "updates active theme and triggers on_change listener" do
      changed_theme = ""
      Opal::ThemeStore.on_change do |t|
        changed_theme = t.name
      end

      Opal::ThemeStore.current = :nord
      Opal::ThemeStore.current.name.should eq("nord")
      changed_theme.should eq("nord")

      # Restore default
      Opal::ThemeStore.current = :catppuccin_mocha
      Opal::ThemeStore.clear_listeners
    end
  end

  describe "JSON Serialization & Import" do
    it "exports and imports custom themes via JSON" do
      original = Opal::Theme.new(
        name: "neon_custom",
        primary: Opal::Color.hex("#123456"),
        secondary: Opal::Color.hex("#234567"),
        accent: Opal::Color.hex("#345678"),
        background: Opal::Color.hex("#010203"),
        surface: Opal::Color.hex("#040506"),
        text: Opal::Color.hex("#FAFAFA"),
        text_muted: Opal::Color.hex("#888888"),
        border: Opal::Color.hex("#444444"),
        success: Opal::Color.hex("#00FF00"),
        warning: Opal::Color.hex("#FFFF00"),
        danger: Opal::Color.hex("#FF0000"),
        info: Opal::Color.hex("#0000FF")
      )

      json_str = Opal::ThemeStore.export_json(original)
      imported = Opal::ThemeStore.import_json(json_str)

      imported.name.should eq("neon_custom")
      imported.primary.to_hex.should eq("#123456")
      imported.background.to_hex.should eq("#010203")
      imported.text.to_hex.should eq("#FAFAFA")
      Opal::ThemeStore.has?("neon_custom").should be_true
    end
  end

  describe "WCAG 2.1 Contrast Ratio Analysis" do
    it "accurately calculates contrast ratio" do
      white = Opal::Color.rgb(255, 255, 255)
      black = Opal::Color.rgb(0, 0, 0)

      # Black on white: 21:1
      white.contrast_ratio(black).should be_close(21.0, 0.1)
      black.contrast_ratio(white).should be_close(21.0, 0.1)

      # Identical colors: 1:1
      white.contrast_ratio(white).should be_close(1.0, 0.01)
    end

    it "identifies readable color pairs meeting WCAG AA ratio (4.5:1)" do
      white = Opal::Color.rgb(255, 255, 255)
      dark_bg = Opal::Color.rgb(20, 20, 30)
      white.readable_against?(dark_bg).should be_true

      # Low contrast pair (dark gray on black)
      dark_gray = Opal::Color.rgb(40, 40, 40)
      dark_gray.readable_against?(dark_bg).should be_false
    end

    it "generates contrast analysis report for themes" do
      hc = Opal::ThemeStore.get("high_contrast")
      report = Opal::ThemeStore.contrast_analysis(hc)
      report["text_on_background"].should be >= 20.0
    end
  end
end
