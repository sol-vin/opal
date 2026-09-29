require "base64"

module Opal
  module Terminal
    # Operating System Command (OSC) escape sequences for modern terminal emulators.
    module OSC
      # Generates an OSC 8 clickable hyperlink escape sequence.
      # Supported by Windows Terminal, iTerm2, Kitty, WezTerm, Alacritty, GNOME Terminal, etc.
      def self.hyperlink(text : String, url : String, id : String? = nil) : String
        params = id ? "id=#{id}" : ""
        "\e]8;#{params};#{url}\e\\#{text}\e]8;;\e\\"
      end

      # Generates an OSC 52 clipboard copy escape sequence using strict Base64 encoding.
      # Allows copying text directly into the host OS clipboard over SSH and local terminal sessions.
      # clipboard target: 'c' = primary clipboard, 'p' = selection clipboard
      def self.clipboard_copy(text : String, target : Char = 'c') : String
        encoded = Base64.strict_encode(text)
        "\e]52;#{target};#{encoded}\e\\"
      end

      # Directly copies text to the system clipboard via STDOUT using OSC 52.
      def self.copy_to_clipboard(text : String, io : IO = STDOUT, target : Char = 'c') : Nil
        io << clipboard_copy(text, target)
        io.flush
      end
    end
  end
end
