require "./color"
require "./border"
require "./glyph_set"

module Opal
  # Represents a semantic color and styling theme for consistent, accessible TUI interfaces.
  class Theme
    getter name : String
    property primary : Color
    property secondary : Color
    property accent : Color
    property background : Color
    property surface : Color
    property text : Color
    property text_muted : Color
    property border : Color
    property success : Color
    property warning : Color
    property danger : Color
    property info : Color
    property window_border : Border
    property box_border : Border
    property glyphs : GlyphSet

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
      @window_border : Border = Border.rounded,
      @box_border : Border = Border.rounded,
      @glyphs : GlyphSet = GlyphSet.new,
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

    def self.find(name : Symbol | String) : Theme?
      @@themes[name.to_s.downcase]?
    end

    def self.[](name : Symbol | String) : Theme
      get(name)
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

    # Returns a new theme derived from this theme with selective overrides
    def derive(
      name : String,
      primary : Color | String | Symbol | Nil = nil,
      secondary : Color | String | Symbol | Nil = nil,
      accent : Color | String | Symbol | Nil = nil,
      background : Color | String | Symbol | Nil = nil,
      surface : Color | String | Symbol | Nil = nil,
      text : Color | String | Symbol | Nil = nil,
      text_muted : Color | String | Symbol | Nil = nil,
      border : Color | String | Symbol | Nil = nil,
      success : Color | String | Symbol | Nil = nil,
      warning : Color | String | Symbol | Nil = nil,
      danger : Color | String | Symbol | Nil = nil,
      info : Color | String | Symbol | Nil = nil,
      window_border : Border | Symbol | String | Nil = nil,
      box_border : Border | Symbol | String | Nil = nil,
      glyphs : GlyphSet? = nil,
    ) : Theme
      Theme.new(
        name: name,
        primary: primary ? Color.from(primary) : @primary,
        secondary: secondary ? Color.from(secondary) : @secondary,
        accent: accent ? Color.from(accent) : @accent,
        background: background ? Color.from(background) : @background,
        surface: surface ? Color.from(surface) : @surface,
        text: text ? Color.from(text) : @text,
        text_muted: text_muted ? Color.from(text_muted) : @text_muted,
        border: border ? Color.from(border) : @border,
        success: success ? Color.from(success) : @success,
        warning: warning ? Color.from(warning) : @warning,
        danger: danger ? Color.from(danger) : @danger,
        info: info ? Color.from(info) : @info,
        window_border: window_border ? Border.from(window_border) : @window_border,
        box_border: box_border ? Border.from(box_border) : @box_border,
        glyphs: glyphs || @glyphs,
      )
    end

    # Generates a balanced, harmonious theme from a single brand color and dark/light mode
    def self.from_brand(name : String, brand : Color | String | Symbol, mode : Symbol = :dark) : Theme
      pri = Color.from(brand)
      if mode == :dark
        bg = Color.hex("#0F172A")
        surf = Color.hex("#1E293B")
        txt = Color.hex("#F8FAFC")
        txt_m = Color.hex("#94A3B8")
        brd = Color.hex("#334155")
      else
        bg = Color.hex("#F8FAFC")
        surf = Color.hex("#F1F5F9")
        txt = Color.hex("#0F172A")
        txt_m = Color.hex("#64748B")
        brd = Color.hex("#CBD5E1")
      end

      sec = pri.darken(0.15)
      acc = pri.lighten(0.2)

      theme = Theme.new(
        name: name,
        primary: pri,
        secondary: sec,
        accent: acc,
        background: bg,
        surface: surf,
        text: txt,
        text_muted: txt_m,
        border: brd,
        success: Color.hex("#10B981"),
        warning: Color.hex("#F59E0B"),
        danger: Color.hex("#EF4444"),
        info: Color.hex("#3B82F6")
      )
      theme.ensure_contrast
    end

    # Adjusts text and primary contrast against background to satisfy minimum WCAG ratio
    def ensure_contrast(min_ratio : Float64 = 4.5) : Theme
      @text = @text.ensure_contrast(@background, min_ratio)
      @primary = @primary.ensure_contrast(@background, min_ratio)
      self
    end

    # Audits theme contrast ratios against WCAG 2.1 criteria
    def audit_contrast : Hash(String, NamedTuple(ratio: Float64, compliant: Bool, level: String))
      pairs = {
        "text_on_background"       => {@text, @background},
        "text_on_surface"          => {@text, @surface},
        "text_muted_on_background" => {@text_muted, @background},
        "primary_on_background"    => {@primary, @background},
        "accent_on_background"     => {@accent, @background},
      }
      res = Hash(String, NamedTuple(ratio: Float64, compliant: Bool, level: String)).new
      pairs.each do |k, (fg, bg)|
        ratio = fg.contrast_ratio(bg)
        level = if ratio >= 7.0
                  "AAA (7.0+)"
                elsif ratio >= 4.5
                  "AA (4.5+)"
                elsif ratio >= 3.0
                  "AA-Large (3.0+)"
                else
                  "FAIL (<3.0)"
                end
        res[k] = {ratio: ratio.round(2), compliant: ratio >= 4.5, level: level}
      end
      res
    end

    # Declarative Theme Builder DSL entry point
    def self.build(name : String, &block : ThemeBuilder -> Nil) : Theme
      builder = ThemeBuilder.new(name)
      block.call(builder)
      theme = builder.build
      register(theme)
      theme
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
      border: Color.hex("#4C566A"),
      success: Color.hex("#A3BE8C"),
      warning: Color.hex("#EBCB8B"),
      danger: Color.hex("#BF616A"),
      info: Color.hex("#5E81AC")
    ))

    register(Theme.new(
      name: "monokai",
      primary: Color.hex("#A6E22E"),
      secondary: Color.hex("#66D9EF"),
      accent: Color.hex("#F92672"),
      background: Color.hex("#272822"),
      surface: Color.hex("#3E3D32"),
      text: Color.hex("#F8F8F2"),
      text_muted: Color.hex("#75715E"),
      border: Color.hex("#49483E"),
      success: Color.hex("#A6E22E"),
      warning: Color.hex("#E6DB74"),
      danger: Color.hex("#F92672"),
      info: Color.hex("#66D9EF")
    ))

    register(Theme.new(
      name: "tokyo_night",
      primary: Color.hex("#7AA2F7"),
      secondary: Color.hex("#2AC3DE"),
      accent: Color.hex("#BB9AF7"),
      background: Color.hex("#1A1B26"),
      surface: Color.hex("#24283B"),
      text: Color.hex("#C0CAF5"),
      text_muted: Color.hex("#565F89"),
      border: Color.hex("#414868"),
      success: Color.hex("#9ECE6A"),
      warning: Color.hex("#E0AF68"),
      danger: Color.hex("#F7768E"),
      info: Color.hex("#7DCFFF")
    ))

    register(Theme.new(
      name: "gruvbox",
      primary: Color.hex("#FABD2F"),
      secondary: Color.hex("#83A598"),
      accent: Color.hex("#D3869B"),
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

    register(Theme.new(
      name: "cyberpunk",
      primary: Color.hex("#FF007F"),
      secondary: Color.hex("#00F0FF"),
      accent: Color.hex("#FFE600"),
      background: Color.hex("#080811"),
      surface: Color.hex("#121324"),
      text: Color.hex("#FFFFFF"),
      text_muted: Color.hex("#707590"),
      border: Color.hex("#303550"),
      success: Color.hex("#00FF66"),
      warning: Color.hex("#FFE600"),
      danger: Color.hex("#FF0055"),
      info: Color.hex("#00F0FF")
    ))

    def self.default : Theme
      get("catppuccin_mocha")
    end

    def self.catppuccin_mocha : Theme
      get("catppuccin_mocha")
    end

    def self.catppuccin_latte : Theme
      get("catppuccin_latte")
    end

    def self.dracula : Theme
      get("dracula")
    end

    def self.nord : Theme
      get("nord")
    end

    def self.monokai : Theme
      get("monokai")
    end

    def self.tokyo_night : Theme
      get("tokyo_night")
    end

    def self.gruvbox : Theme
      get("gruvbox")
    end

    def self.solarized_dark : Theme
      get("solarized_dark")
    end

    def self.high_contrast : Theme
      get("high_contrast")
    end

    def self.cyberpunk : Theme
      get("cyberpunk")
    end
  end

  # Fluent Builder DSL for defining custom themes with auto-derivation and validation
  class ThemeBuilder
    property name : String
    property primary : Color?
    property secondary : Color?
    property accent : Color?
    property background : Color?
    property surface : Color?
    property text : Color?
    property text_muted : Color?
    property border : Color?
    property success : Color?
    property warning : Color?
    property danger : Color?
    property info : Color?
    property window_border : Border
    property box_border : Border
    property glyphs : GlyphSet

    def initialize(@name : String)
      @window_border = Border.rounded
      @box_border = Border.rounded
      @glyphs = GlyphSet.new
    end

    # Fluent setter methods
    def primary(c : Color | String | Symbol) : self
      @primary = Color.from(c)
      self
    end

    def secondary(c : Color | String | Symbol) : self
      @secondary = Color.from(c)
      self
    end

    def accent(c : Color | String | Symbol) : self
      @accent = Color.from(c)
      self
    end

    def background(c : Color | String | Symbol) : self
      @background = Color.from(c)
      self
    end

    def surface(c : Color | String | Symbol) : self
      @surface = Color.from(c)
      self
    end

    def text(c : Color | String | Symbol) : self
      @text = Color.from(c)
      self
    end

    def text_muted(c : Color | String | Symbol) : self
      @text_muted = Color.from(c)
      self
    end

    def border(c : Color | String | Symbol) : self
      @border = Color.from(c)
      self
    end

    def success(c : Color | String | Symbol) : self
      @success = Color.from(c)
      self
    end

    def warning(c : Color | String | Symbol) : self
      @warning = Color.from(c)
      self
    end

    def danger(c : Color | String | Symbol) : self
      @danger = Color.from(c)
      self
    end

    def info(c : Color | String | Symbol) : self
      @info = Color.from(c)
      self
    end

    def window_border(b : Border | Symbol | String) : self
      @window_border = Border.from(b)
      self
    end

    def box_border(b : Border | Symbol | String) : self
      @box_border = Border.from(b)
      self
    end

    def glyphs(&block : GlyphSet -> GlyphSet) : self
      @glyphs = block.call(@glyphs)
      self
    end

    # Nested colors block
    def colors(&block : ThemeBuilder -> Nil) : self
      block.call(self)
      self
    end

    # Nested borders block
    def borders(&block : ThemeBuilder -> Nil) : self
      block.call(self)
      self
    end

    # Compiles and auto-completes missing values
    def build : Theme
      pri = @primary || Color.hex("#6C5CE7")
      bg = @background || Color.hex("#1E1E2E")
      is_dark = bg.relative_luminance < 0.5

      surf = @surface || (is_dark ? bg.lighten(0.08) : bg.darken(0.08))
      txt = @text || (is_dark ? Color.hex("#F8FAFC") : Color.hex("#0F172A"))
      txt_m = @text_muted || (is_dark ? txt.darken(0.35) : txt.lighten(0.35))
      brd = @border || (is_dark ? surf.lighten(0.12) : surf.darken(0.12))

      sec = @secondary || pri.darken(0.15)
      acc = @accent || pri.lighten(0.2)

      suc = @success || Color.hex("#10B981")
      war = @warning || Color.hex("#F59E0B")
      dan = @danger || Color.hex("#EF4444")
      inf = @info || Color.hex("#3B82F6")

      theme = Theme.new(
        name: @name,
        primary: pri,
        secondary: sec,
        accent: acc,
        background: bg,
        surface: surf,
        text: txt,
        text_muted: txt_m,
        border: brd,
        success: suc,
        warning: war,
        danger: dan,
        info: inf,
        window_border: @window_border,
        box_border: @box_border,
        glyphs: @glyphs
      )
      theme.ensure_contrast
    end
  end

  # Top-level DSL helper: Opal.theme "my_theme" do |t| ... end
  def self.theme(name : String, &block : ThemeBuilder -> Nil) : Theme
    Theme.build(name, &block)
  end
end
