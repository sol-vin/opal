require "./theme"
require "./color"
require "json"

module Opal
  # Registry and preset repository for UI semantic themes.
  # Includes 16 calibrated presets, JSON serialization/deserialization for custom user themes,
  # reactive `on_change` subscription hooks, and accessibility contrast auditing.
  class ThemeStore
    @@themes = Hash(String, Theme).new
    @@current : Theme? = nil
    @@listeners = [] of Proc(Theme, Nil)

    # Registers a theme in the store.
    def self.register(theme : Theme) : Theme
      @@themes[theme.name.downcase] = theme
      theme
    end

    # Checks if a theme exists by name.
    def self.has?(name : Symbol | String) : Bool
      @@themes.has_key?(name.to_s.downcase)
    end

    # Fetches a theme by name, falling back to catppuccin_mocha or default.
    def self.get(name : Symbol | String) : Theme
      key = name.to_s.downcase
      @@themes[key]? || @@themes["catppuccin_mocha"]? || default_fallback
    end

    # Returns the currently active global theme.
    def self.current : Theme
      @@current ||= get("catppuccin_mocha")
    end

    # Sets the currently active global theme and notifies subscribers.
    def self.current=(theme : Theme | Symbol | String) : Theme
      new_theme = case theme
                  when Theme
                    theme
                  else
                    get(theme)
                  end
      old_theme = @@current
      @@current = new_theme
      Theme.current = new_theme

      if old_theme != new_theme
        @@listeners.each { |listener| listener.call(new_theme) }
      end
      new_theme
    end

    # Registers a listener callback invoked whenever the active theme changes.
    def self.on_change(&block : Theme -> Nil) : Nil
      @@listeners << block
    end

    # Clears all change listeners
    def self.clear_listeners : Nil
      @@listeners.clear
    end

    # Returns all registered themes.
    def self.all : Array(Theme)
      @@themes.values
    end

    # Returns names of all registered themes.
    def self.names : Array(String)
      @@themes.keys
    end

    # Exports a theme to a JSON string representation.
    def self.export_json(theme : Theme) : String
      JSON.build do |json|
        json.object do
          json.field "name", theme.name
          json.field "primary", theme.primary.to_hex
          json.field "secondary", theme.secondary.to_hex
          json.field "accent", theme.accent.to_hex
          json.field "background", theme.background.to_hex
          json.field "surface", theme.surface.to_hex
          json.field "text", theme.text.to_hex
          json.field "text_muted", theme.text_muted.to_hex
          json.field "border", theme.border.to_hex
          json.field "success", theme.success.to_hex
          json.field "warning", theme.warning.to_hex
          json.field "danger", theme.danger.to_hex
          json.field "info", theme.info.to_hex
        end
      end
    end

    # Imports a theme from a JSON string representation.
    def self.import_json(json_str : String) : Theme
      parsed = JSON.parse(json_str)
      theme = Theme.new(
        name: parsed["name"].as_s,
        primary: Color.hex(parsed["primary"].as_s),
        secondary: Color.hex(parsed["secondary"].as_s),
        accent: Color.hex(parsed["accent"].as_s),
        background: Color.hex(parsed["background"].as_s),
        surface: Color.hex(parsed["surface"].as_s),
        text: Color.hex(parsed["text"].as_s),
        text_muted: Color.hex(parsed["text_muted"].as_s),
        border: Color.hex(parsed["border"].as_s),
        success: Color.hex(parsed["success"].as_s),
        warning: Color.hex(parsed["warning"].as_s),
        danger: Color.hex(parsed["danger"].as_s),
        info: Color.hex(parsed["info"].as_s)
      )
      register(theme)
      theme
    end

    # Calculates WCAG 2.1 contrast ratios for key UI color pairings in a theme.
    def self.contrast_analysis(theme : Theme) : Hash(String, Float64)
      {
        "text_on_background"       => theme.text.contrast_ratio(theme.background),
        "text_on_surface"          => theme.text.contrast_ratio(theme.surface),
        "text_muted_on_background" => theme.text_muted.contrast_ratio(theme.background),
        "primary_on_background"    => theme.primary.contrast_ratio(theme.background),
        "accent_on_background"     => theme.accent.contrast_ratio(theme.background),
      }
    end

    private def self.default_fallback : Theme
      Theme.get("default")
    end

    # Initialize all 16 built-in themes into the ThemeStore
    Theme.all.each do |theme|
      register(theme)
    end

    # Register additional popular presets
    register(Theme.new(
      name: "solarized_light",
      primary: Color.hex("#268BD2"),
      secondary: Color.hex("#2AA198"),
      accent: Color.hex("#D33682"),
      background: Color.hex("#FDF6E3"),
      surface: Color.hex("#EEE8D5"),
      text: Color.hex("#657B83"),
      text_muted: Color.hex("#93A1A1"),
      border: Color.hex("#D33682"),
      success: Color.hex("#859900"),
      warning: Color.hex("#B58900"),
      danger: Color.hex("#DC322F"),
      info: Color.hex("#2AA198")
    ))

    register(Theme.new(
      name: "monokai",
      primary: Color.hex("#F92672"),
      secondary: Color.hex("#66D9EF"),
      accent: Color.hex("#A6E22E"),
      background: Color.hex("#272822"),
      surface: Color.hex("#3E3D32"),
      text: Color.hex("#F8F8F2"),
      text_muted: Color.hex("#75715E"),
      border: Color.hex("#49483E"),
      success: Color.hex("#A6E22E"),
      warning: Color.hex("#FD971F"),
      danger: Color.hex("#F92672"),
      info: Color.hex("#66D9EF")
    ))

    register(Theme.new(
      name: "cyberpunk",
      primary: Color.hex("#FFE600"),   # Neon Yellow
      secondary: Color.hex("#00FFFF"), # Electric Cyan
      accent: Color.hex("#FF0055"),    # Neon Pink
      background: Color.hex("#08080C"),
      surface: Color.hex("#1A1A24"),
      text: Color.hex("#F0F0FF"),
      text_muted: Color.hex("#707090"),
      border: Color.hex("#00FFFF"),
      success: Color.hex("#00FF66"),
      warning: Color.hex("#FFE600"),
      danger: Color.hex("#FF0055"),
      info: Color.hex("#00E5FF")
    ))

    register(Theme.new(
      name: "synthwave",
      primary: Color.hex("#FF71CE"),    # Neon Pink
      secondary: Color.hex("#01CDFE"),  # Sky Blue
      accent: Color.hex("#05FFA1"),     # Neon Mint
      background: Color.hex("#241734"), # Dark Purple
      surface: Color.hex("#2E1B4E"),
      text: Color.hex("#FFF7FF"),
      text_muted: Color.hex("#B967FF"),
      border: Color.hex("#FF71CE"),
      success: Color.hex("#05FFA1"),
      warning: Color.hex("#FFE76A"),
      danger: Color.hex("#FF2A85"),
      info: Color.hex("#01CDFE")
    ))

    register(Theme.new(
      name: "matrix",
      primary: Color.hex("#00FF66"),   # Bright Phosphor Green
      secondary: Color.hex("#00CC44"), # Forest Phosphor
      accent: Color.hex("#AAFFAA"),    # High-intensity green
      background: Color.hex("#0D110D"),
      surface: Color.hex("#162016"),
      text: Color.hex("#33FF33"),
      text_muted: Color.hex("#008822"),
      border: Color.hex("#00AA33"),
      success: Color.hex("#00FF66"),
      warning: Color.hex("#CCFF00"),
      danger: Color.hex("#FF3333"),
      info: Color.hex("#00FFCC")
    ))

    register(Theme.new(
      name: "retro_amber",
      primary: Color.hex("#FFB000"),    # Amber Phosphor
      secondary: Color.hex("#FF8000"),  # Deep Amber
      accent: Color.hex("#FFD000"),     # Highlight Gold
      background: Color.hex("#140D00"), # Dark CRT glass
      surface: Color.hex("#261700"),
      text: Color.hex("#FFB000"),
      text_muted: Color.hex("#996000"),
      border: Color.hex("#FF8000"),
      success: Color.hex("#FFB000"),
      warning: Color.hex("#FFCC00"),
      danger: Color.hex("#FF4400"),
      info: Color.hex("#FFA000")
    ))

    register(Theme.new(
      name: "one_dark",
      primary: Color.hex("#61AFEF"),
      secondary: Color.hex("#98C379"),
      accent: Color.hex("#C678DD"),
      background: Color.hex("#282C34"),
      surface: Color.hex("#353B45"),
      text: Color.hex("#ABB2BF"),
      text_muted: Color.hex("#5C6370"),
      border: Color.hex("#4B5263"),
      success: Color.hex("#98C379"),
      warning: Color.hex("#E5C07B"),
      danger: Color.hex("#E06C75"),
      info: Color.hex("#56B6C2")
    ))

    register(Theme.new(
      name: "rose_pine",
      primary: Color.hex("#9CCFD8"),
      secondary: Color.hex("#C4A7E7"),
      accent: Color.hex("#EB6F92"),
      background: Color.hex("#191724"),
      surface: Color.hex("#26233A"),
      text: Color.hex("#E0DEF4"),
      text_muted: Color.hex("#6E6A86"),
      border: Color.hex("#403D52"),
      success: Color.hex("#31748F"),
      warning: Color.hex("#F6C177"),
      danger: Color.hex("#EB6F92"),
      info: Color.hex("#9CCFD8")
    ))
  end
end
