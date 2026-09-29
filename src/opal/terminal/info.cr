require "./screen"

module Opal
  module Terminal
    enum ColorProfile
      TrueColor
      ANSI256
      ANSI16
      Monochrome
      None
    end

    # Inspects and queries terminal emulator capabilities, dimensions, and environment.
    class Info
      getter width : Int32
      getter height : Int32
      getter color_profile : ColorProfile
      getter? tty : Bool
      getter term_program : String?

      def initialize(driver : Driver? = nil)
        w, h = driver ? driver.size : default_size
        @width = w
        @height = h
        @tty = STDOUT.tty? rescue false
        @color_profile = detect_color_profile
        @term_program = detect_term_program
      end

      # Reloads dynamic values such as terminal window dimensions
      def refresh!(driver : Driver? = nil) : self
        w, h = driver ? driver.size : default_size
        @width = w
        @height = h
        self
      end

      def columns : Int32
        @width
      end

      def rows : Int32
        @height
      end

      def size : {Int32, Int32}
        {@width, @height}
      end

      def truecolor? : Bool
        @color_profile == ColorProfile::TrueColor
      end

      def colors_256? : Bool
        @color_profile == ColorProfile::TrueColor || @color_profile == ColorProfile::ANSI256
      end

      def colors_enabled? : Bool
        @color_profile != ColorProfile::None && @color_profile != ColorProfile::Monochrome
      end

      def windows? : Bool
        {% if flag?(:windows) %} true {% else %} false {% end %}
      end

      def posix? : Bool
        !windows?
      end

      def linux? : Bool
        {% if flag?(:linux) %} true {% else %} false {% end %}
      end

      def darwin? : Bool
        {% if flag?(:darwin) %} true {% else %} false {% end %}
      end

      def supports_mouse? : Bool
        return false unless @tty
        true
      end

      def supports_alt_screen? : Bool
        return false unless @tty
        env_term = ENV["TERM"]?.try(&.downcase) || ""
        env_term != "dumb"
      end

      def supports_hyperlinks? : Bool
        return false unless @tty
        tp = @term_program.try(&.downcase) || ""
        ["wezterm", "iterm.app", "iterm2", "alacritty", "vscode", "windows terminal", "kitty", "foot", "mintty"].any? { |prog| tp.includes?(prog) }
      end

      private def default_size : {Int32, Int32}
        cols = ENV["COLUMNS"]?.try(&.to_i?) || 80
        rows = ENV["LINES"]?.try(&.to_i?) || 24
        {cols, rows}
      end

      private def detect_color_profile : ColorProfile
        return ColorProfile::None if !ENV["NO_COLOR"]?.nil? && !ENV["NO_COLOR"]?.try(&.empty?)
        return ColorProfile::None if ENV["TERM"]? == "dumb"

        colorterm = ENV["COLORTERM"]?.try(&.downcase) || ""
        return ColorProfile::TrueColor if colorterm == "truecolor" || colorterm == "24bit"

        # Windows 10/11 Terminal and modern ConPTY support TrueColor
        if windows? && (ENV["WT_SESSION"]? || ENV["ConEmuPID"]?)
          return ColorProfile::TrueColor
        end

        term = ENV["TERM"]?.try(&.downcase) || ""
        return ColorProfile::ANSI256 if term.includes?("256color") || term.includes?("kitty") || term.includes?("alacritty")
        return ColorProfile::ANSI16 if term.includes?("color") || term.includes?("ansi") || term.includes?("xterm") || term.includes?("vt100")

        return ColorProfile::ANSI16 if @tty

        ColorProfile::None
      end

      private def detect_term_program : String?
        return "Windows Terminal" if ENV["WT_SESSION"]?
        return "ConEmu" if ENV["ConEmuPID"]?
        return "VSCode" if ENV["TERM_PROGRAM"]? == "vscode" || ENV["VSCODE_INJECTION"]?
        return "iTerm2" if ENV["TERM_PROGRAM"]? == "iTerm.app"
        return "Alacritty" if ENV["ALACRITTY_LOG"]? || ENV["TERM"]?.try(&.includes?("alacritty"))
        return "Kitty" if ENV["KITTY_WINDOW_ID"]? || ENV["TERM"]?.try(&.includes?("kitty"))
        return "WezTerm" if ENV["WEZTERM_EXECUTABLE"]? || ENV["TERM_PROGRAM"]? == "WezTerm"
        return "tmux" if ENV["TMUX"]?
        ENV["TERM_PROGRAM"]?
      end
    end
  end

  # Returns terminal information object
  def self.terminal : Terminal::Info
    @@terminal_info ||= Terminal::Info.new
  end

  # Executes a block with the terminal information DSL
  def self.terminal(&block : Terminal::Info -> T) : T forall T
    yield terminal
  end
end
