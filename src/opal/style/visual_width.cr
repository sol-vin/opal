module Opal
  # Utilities for computing string display width in terminal columns, accounting for ANSI escapes,
  # East Asian wide characters, and Unicode emojis.
  module VisualWidth
    ANSI_REGEX = /\e\[[0-9;?]*[a-zA-Z]|\e\].*?(?:\a|\e\\)/

    # Removes all ANSI escape codes from the string.
    def self.strip_ansi(str : String) : String
      str.gsub(ANSI_REGEX, "")
    end

    # Returns the visual column width of a character when printed on a terminal.
    def self.char_width(char : Char) : Int32
      cp = char.ord

      # Non-printing / zero-width controls and modifiers
      return 0 if cp < 32 || (cp >= 127 && cp < 160)
      return 0 if cp == 0x200B                 # Zero-width space
      return 0 if cp >= 0xFE00 && cp <= 0xFE0F # Variation selectors
      return 0 if cp >= 0x0300 && cp <= 0x036F # Combining diacritical marks

      # East Asian Wide and Fullwidth characters
      if (cp >= 0x1100 && cp <= 0x115F) ||   # Hangul Jamo
         (cp >= 0x2E80 && cp <= 0xA4CF) ||   # CJK Radicals, Ideographs, Yi
         (cp >= 0xAC00 && cp <= 0xD7A3) ||   # Hangul Syllables
         (cp >= 0xF900 && cp <= 0xFAFF) ||   # CJK Compatibility Ideographs
         (cp >= 0xFE10 && cp <= 0xFE19) ||   # Vertical forms
         (cp >= 0xFE30 && cp <= 0xFE6F) ||   # CJK Compatibility Forms
         (cp >= 0xFF01 && cp <= 0xFF60) ||   # Fullwidth forms
         (cp >= 0xFFE0 && cp <= 0xFFE6) ||   # Fullwidth symbols
         (cp >= 0x1F300 && cp <= 0x1FAFF) || # Miscellaneous Symbols, Pictographs, Emojis
         (cp >= 0x20000 && cp <= 0x2FA1F)    # CJK Unified Extension
        return 2
      end

      1
    end

    # Returns the total visual column width of a string.
    def self.width(str : String) : Int32
      clean = strip_ansi(str)
      clean.chars.sum { |c| char_width(c) }
    end

    # Truncates a string to fit within max_width terminal columns, appending ellipsis if needed.
    def self.truncate(str : String, max_width : Int32, ellipsis : String = "...") : String
      return str if width(str) <= max_width

      target_width = max_width - width(ellipsis)
      return ellipsis[0...max_width] if target_width <= 0

      current_width = 0
      io = IO::Memory.new
      clean = strip_ansi(str)

      clean.each_char do |ch|
        cw = char_width(ch)
        break if current_width + cw > target_width
        io << ch
        current_width += cw
      end

      io << ellipsis
      io.to_s
    end
  end
end
