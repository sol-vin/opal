require "./color"

module Opal
  # Represents a semantic color theme for consistent, accessible TUI styling.
  class Theme
    getter name : String
    getter primary : Color
    getter secondary : Color
    getter accent : Color
    getter background : Color
    getter surface : Color
    getter text : Color
    getter text_muted : Color
    getter border : Color
    getter success : Color
    getter warning : Color
    getter danger : Color
    getter info : Color

    def initialize(
      @name : String,
      @primary : Color,
      @secondary : Color,
      @accent : Color,
      @background : Color,
      @surface : Color,
      @text : Color,
      @text_muted : Color,
      @border : Color,
      @success : Color,
      @warning : Color,
      @danger : Color,
      @info : Color,
    )
    end

    @@themes = Hash(String, Theme).new
    @@current : Theme? = nil

    def self.register(theme : Theme) : Theme
      @@themes[theme.name.downcase] = theme
      theme
    end

    def self.get(name : Symbol | String) : Theme
      key = name.to_s.downcase
      @@themes[key]? || @@themes["catppuccin_mocha"]? || default_fallback
    end

    def self.current : Theme
      @@current ||= get("catppuccin_mocha")
    end

    def self.current=(theme : Theme | Symbol | String) : Theme
      case theme
      when Theme
        @@current = theme
      else
        @@current = get(theme)
      end
      @@current.not_nil!
    end

    def self.all : Array(Theme)
      @@themes.values
    end

    private def self.default_fallback : Theme
      Theme.new(
        name: "default",
        primary: Color.hex("#6C5CE7"),
        secondary: Color.hex("#00CEC9"),
        accent: Color.hex("#FD79A8"),
        background: Color.hex("#2D3436"),
        surface: Color.hex("#636E72"),
        text: Color.hex("#DFE6E9"),
        text_muted: Color.hex("#B2BEC3"),
        border: Color.hex("#B2BEC3"),
        success: Color.hex("#00B894"),
        warning: Color.hex("#FDCB6E"),
        danger: Color.hex("#D63031"),
        info: Color.hex("#0984E3")
      )
    end

    # Pre-register standard built-in themes
    register(Theme.new(
      name: "catppuccin_mocha",
      primary: Color.hex("#CBA6F7"),
      secondary: Color.hex("#89B4FA"),
      accent: Color.hex("#F5C2E7"),
      background: Color.hex("#1E1E2E"),
      surface: Color.hex("#313244"),
      text: Color.hex("#CDD6F4"),
      text_muted: Color.hex("#6C7086"),
      border: Color.hex("#45475A"),
      success: Color.hex("#A6E3A1"),
      warning: Color.hex("#F9E2AF"),
      danger: Color.hex("#F38BA8"),
      info: Color.hex("#89DCEB")
    ))

    register(Theme.new(
      name: "catppuccin_latte",
      primary: Color.hex("#8839EF"),
      secondary: Color.hex("#1E66F5"),
      accent: Color.hex("#EA76CB"),
      background: Color.hex("#EFF1F5"),
      surface: Color.hex("#CCD0DA"),
      text: Color.hex("#4C4F69"),
      text_muted: Color.hex("#9CA0B0"),
      border: Color.hex("#BCC0CC"),
      success: Color.hex("#40A02B"),
      warning: Color.hex("#DF8E1D"),
      danger: Color.hex("#D20F39"),
      info: Color.hex("#04A5E5")
    ))

    register(Theme.new(
      name: "dracula",
      primary: Color.hex("#BD93F9"),
      secondary: Color.hex("#8BE9FD"),
      accent: Color.hex("#FF79C6"),
      background: Color.hex("#282A36"),
      surface: Color.hex("#44475A"),
      text: Color.hex("#F8F8F2"),
      text_muted: Color.hex("#6272A4"),
      border: Color.hex("#6272A4"),
      success: Color.hex("#50FA7B"),
      warning: Color.hex("#F1FA8C"),
      danger: Color.hex("#FF5555"),
      info: Color.hex("#8BE9FD")
    ))

    register(Theme.new(
      name: "nord",
      primary: Color.hex("#88C0D0"),
      secondary: Color.hex("#81A1C1"),
      accent: Color.hex("#B48EAD"),
      background: Color.hex("#2E3440"),
      surface: Color.hex("#3B4252"),
      text: Color.hex("#ECEFF4"),
      text_muted: Color.hex("#4C566A"),
      border: Color.hex("#434C5E"),
      success: Color.hex("#A3BE8C"),
      warning: Color.hex("#EBCB8B"),
      danger: Color.hex("#BF616A"),
      info: Color.hex("#8FBCBB")
    ))

    register(Theme.new(
      name: "tokyo_night",
      primary: Color.hex("#7AA2F7"),
      secondary: Color.hex("#BB9AF7"),
      accent: Color.hex("#7DCFFF"),
      background: Color.hex("#1A1B26"),
      surface: Color.hex("#24283B"),
      text: Color.hex("#C0CAF5"),
      text_muted: Color.hex("#565F89"),
      border: Color.hex("#414868"),
      success: Color.hex("#9ECE6A"),
      warning: Color.hex("#E0AF68"),
      danger: Color.hex("#F7768E"),
      info: Color.hex("#2AC3DE")
    ))

    register(Theme.new(
      name: "gruvbox",
      primary: Color.hex("#FE8019"),
      secondary: Color.hex("#FABD2F"),
      accent: Color.hex("#B8BB26"),
      background: Color.hex("#282828"),
      surface: Color.hex("#3C3836"),
      text: Color.hex("#EBDBB2"),
      text_muted: Color.hex("#928374"),
      border: Color.hex("#504945"),
      success: Color.hex("#B8BB26"),
      warning: Color.hex("#FABD2F"),
      danger: Color.hex("#FB4934"),
      info: Color.hex("#83A598")
    ))

    register(Theme.new(
      name: "solarized_dark",
      primary: Color.hex("#268BD2"),
      secondary: Color.hex("#2AA198"),
      accent: Color.hex("#D33682"),
      background: Color.hex("#002B36"),
      surface: Color.hex("#073642"),
      text: Color.hex("#839496"),
      text_muted: Color.hex("#586E75"),
      border: Color.hex("#073642"),
      success: Color.hex("#859900"),
      warning: Color.hex("#B58900"),
      danger: Color.hex("#DC322F"),
      info: Color.hex("#2AA198")
    ))

    register(Theme.new(
      name: "high_contrast",
      primary: Color.hex("#FFFFFF"),
      secondary: Color.hex("#00FFFF"),
      accent: Color.hex("#FFFF00"),
      background: Color.hex("#000000"),
      surface: Color.hex("#202020"),
      text: Color.hex("#FFFFFF"),
      text_muted: Color.hex("#808080"),
      border: Color.hex("#FFFFFF"),
      success: Color.hex("#00FF00"),
      warning: Color.hex("#FFFF00"),
      danger: Color.hex("#FF0000"),
      info: Color.hex("#00FFFF")
    ))
  end
end
