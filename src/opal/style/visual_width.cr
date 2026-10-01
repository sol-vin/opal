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

      # East Asian Wide, Fullwidth characters, and Unicode Emojis
      if (cp >= 0x1F000 && cp <= 0x1FAFF) ||               # Miscellaneous Symbols and Pictographs, Emoticons, Supplemental
         (cp >= 0x20000 && cp <= 0x2FA1F) ||               # CJK Unified Extension
         (cp >= 0x1100 && cp <= 0x115F) ||                 # Hangul Jamo
         (cp >= 0x2E80 && cp <= 0xA4CF) ||                 # CJK Radicals, Ideographs, Yi
         (cp >= 0xAC00 && cp <= 0xD7A3) ||                 # Hangul Syllables
         (cp >= 0xF900 && cp <= 0xFAFF) ||                 # CJK Compatibility Ideographs
         (cp >= 0xFE10 && cp <= 0xFE19) ||                 # Vertical forms
         (cp >= 0xFE30 && cp <= 0xFE6F) ||                 # CJK Compatibility Forms
         (cp >= 0xFF01 && cp <= 0xFF60) ||                 # Fullwidth forms
         (cp >= 0xFFE0 && cp <= 0xFFE6) ||                 # Fullwidth symbols
         (cp == 0x231A || cp == 0x231B) ||                 # Time symbols
         (cp >= 0x23E9 && cp <= 0x23EC) ||                 # Media controls
         (cp == 0x23F0 || cp == 0x23F3) ||                 # Clock symbols
         (cp == 0x25FD || cp == 0x25FE) ||                 # Medium squares
         (cp >= 0x2614 && cp <= 0x2615) ||                 # Weather / beverage
         (cp >= 0x2648 && cp <= 0x2653) ||                 # Zodiac symbols
         (cp == 0x267F) ||                                 # Accessibility symbol
         (cp == 0x2693) ||                                 # Anchor
         (cp >= 0x26A0 && cp <= 0x26A1) ||                 # Warning / electrical
         (cp >= 0x26AA && cp <= 0x26AB) ||                 # Medium circles
         (cp >= 0x26BD && cp <= 0x26BE) ||                 # Sport balls
         (cp >= 0x26C4 && cp <= 0x26C5) ||                 # Weather symbols
         (cp == 0x26CE || cp == 0x26D4) ||                 # Zodiac / traffic
         (cp == 0x26EA) ||                                 # Building
         (cp >= 0x26F2 && cp <= 0x26F3) ||                 # Landmark symbols
         (cp == 0x26F5 || cp == 0x26FA || cp == 0x26FD) || # Transport / fuel
         (cp == 0x2705) ||                                 # Check mark
         (cp >= 0x270A && cp <= 0x270B) ||                 # Hand symbols
         (cp == 0x2728) ||                                 # Sparkle
         (cp == 0x274C || cp == 0x274E) ||                 # Cross marks
         (cp >= 0x2753 && cp <= 0x2755) ||                 # Question marks
         (cp == 0x2757) ||                                 # Exclamation mark
         (cp >= 0x2795 && cp <= 0x2797) ||                 # Math signs
         (cp == 0x27B0 || cp == 0x27BF) ||                 # Curly loops
         (cp >= 0x2B1B && cp <= 0x2B1C) ||                 # Large squares
         (cp == 0x2B50 || cp == 0x2B55)                    # Star / circle
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
