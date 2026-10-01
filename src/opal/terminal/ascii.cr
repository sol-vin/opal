module Opal
  # Comprehensive enumeration of standard ASCII (0-127) control and printable codes,
  # alongside Code Page 437 extended terminal UI pieces (arrows, box drawing, blocks, shades, symbols).
  #
  # This provides a canonical, emoji-free reference for all terminal UI characters.
  enum AsciiCode : Int32
    # --- Standard ASCII C0 Control Codes (0-31, 127) ---
    Nul             =   0 # Null byte (\0)
    StartOfHeading  =   1 # SOH
    StartOfText     =   2 # STX
    EndOfText       =   3 # ETX / Ctrl+C / Break
    EndOfTransmit   =   4 # EOT / Ctrl+D
    Enquiry         =   5 # ENQ
    Acknowledge     =   6 # ACK
    Bell            =   7 # BEL / Alert (\a)
    Backspace       =   8 # BS (\b)
    Tab             =   9 # Horizontal Tab (\t)
    LineFeed        =  10 # LF (\n)
    VerticalTab     =  11 # VT (\v)
    FormFeed        =  12 # FF (\f)
    CarriageReturn  =  13 # CR (\r)
    ShiftOut        =  14 # SO
    ShiftIn         =  15 # SI
    DataLinkEscape  =  16 # DLE
    DeviceControl1  =  17 # DC1 / XON
    DeviceControl2  =  18 # DC2
    DeviceControl3  =  19 # DC3 / XOFF
    DeviceControl4  =  20 # DC4
    NegativeAck     =  21 # NAK
    SynchronousIdle =  22 # SYN
    EndOfBlock      =  23 # ETB
    Cancel          =  24 # CAN
    EndOfMedium     =  25 # EM
    Substitute      =  26 # SUB / Ctrl+Z
    Escape          =  27 # ESC (\e)
    FileSeparator   =  28 # FS
    GroupSeparator  =  29 # GS
    RecordSeparator =  30 # RS
    UnitSeparator   =  31 # US
    Delete          = 127 # DEL

    # --- Standard ASCII Printable Characters (32-126) ---
    Space       = 32 # ' '
    Exclamation = 33 # '!'
    DoubleQuote = 34 # '"'
    Hash        = 35 # '#'
    Dollar      = 36 # '$'
    Percent     = 37 # '%'
    Ampersand   = 38 # '&'
    SingleQuote = 39 # '\''
    ParenOpen   = 40 # '('
    ParenClose  = 41 # ')'
    Asterisk    = 42 # '*'
    Plus        = 43 # '+'
    Comma       = 44 # ','
    Hyphen      = 45 # '-'
    Period      = 46 # '.'
    Slash       = 47 # '/'

    # Digits (48-57)
    Digit0 = 48
    Digit1 = 49
    Digit2 = 50
    Digit3 = 51
    Digit4 = 52
    Digit5 = 53
    Digit6 = 54
    Digit7 = 55
    Digit8 = 56
    Digit9 = 57

    Colon     = 58 # ':'
    Semicolon = 59 # ';'
    Less      = 60 # '<'
    Equal     = 61 # '='
    Greater   = 62 # '>'
    Question  = 63 # '?'
    At        = 64 # '@'

    # Brackets & Punctuation
    BracketOpen  =  91 # '['
    Backslash    =  92 # '\\'
    BracketClose =  93 # ']'
    Caret        =  94 # '^'
    Underscore   =  95 # '_'
    Backtick     =  96 # '`'
    BraceOpen    = 123 # '{'
    Pipe         = 124 # '|'
    BraceClose   = 125 # '}'
    Tilde        = 126 # '~'

    # --- Code Page 437 Extended Terminal UI Pieces & Symbols ---
    SmileyFace        = 256 # ☺ (CP437 1)
    SmileyInverse     = 257 # ☻ (CP437 2)
    Heart             = 258 # ♥ (CP437 3)
    Diamond           = 259 # ♦ (CP437 4)
    Club              = 260 # ♣ (CP437 5)
    Spade             = 261 # ♠ (CP437 6)
    Bullet            = 262 # • (CP437 7)
    InverseBullet     = 263 # ◘ (CP437 8)
    CircleOpen        = 264 # ○ (CP437 9)
    CircleInverse     = 265 # ◙ (CP437 10)
    MusicalNote       = 266 # ♪ (CP437 13)
    MusicalNotes      = 267 # ♫ (CP437 14)
    Sun               = 268 # ☼ (CP437 15)
    ArrowRightFill    = 269 # ► (CP437 16)
    ArrowLeftFill     = 270 # ◄ (CP437 17)
    ArrowUpDown       = 271 # ↕ (CP437 18)
    DoubleExclamation = 272 # ‼ (CP437 19)
    Paragraph         = 273 # ¶ (CP437 20)
    Section           = 274 # § (CP437 21)
    RectangleFill     = 275 # ▬ (CP437 22)
    ArrowUpDownBase   = 276 # ↨ (CP437 23)
    ArrowUp           = 277 # ↑ (CP437 24)
    ArrowDown         = 278 # ↓ (CP437 25)
    ArrowRight        = 279 # → (CP437 26)
    ArrowLeft         = 280 # ← (CP437 27)
    RightAngle        = 281 # ∟ (CP437 28)
    LeftRightArrow    = 282 # ↔ (CP437 29)
    TriangleUp        = 283 # ▲ (CP437 30)
    TriangleDown      = 284 # ▼ (CP437 31)

    # Box Drawing & Shading Pieces (CP437 176-223)
    LightShade           = 285 # ░ (CP437 176)
    MediumShade          = 286 # ▒ (CP437 177)
    DarkShade            = 287 # ▓ (CP437 178)
    BoxVertical          = 288 # │ (CP437 179)
    BoxRightTee          = 289 # ┤ (CP437 180)
    BoxVerticalDouble    = 290 # ║ (CP437 186)
    BoxTopRightDouble    = 291 # ╗ (CP437 187)
    BoxBottomRightDouble = 292 # ╝ (CP437 188)
    BoxTopRight          = 293 # ┐ (CP437 191)
    BoxBottomLeft        = 294 # └ (CP437 192)
    BoxBottomTee         = 295 # ┴ (CP437 193)
    BoxTopTee            = 296 # ┬ (CP437 194)
    BoxLeftTee           = 297 # ├ (CP437 195)
    BoxHorizontal        = 298 # ─ (CP437 196)
    BoxCross             = 299 # ┼ (CP437 197)
    BoxBottomRight       = 300 # ┘ (CP437 217)
    BoxTopLeft           = 301 # ┌ (CP437 218)
    BoxFullBlock         = 302 # █ (CP437 219)
    BoxBottomHalf        = 303 # ▄ (CP437 220)
    BoxLeftHalf          = 304 # ▌ (CP437 221)
    BoxRightHalf         = 305 # ▐ (CP437 222)
    BoxTopHalf           = 306 # ▀ (CP437 223)

    # Mathematical & Miscellaneous Pieces
    Degree      = 307 # ° (CP437 248)
    BulletSmall = 308 # ∙ (CP437 249)
    SquareRoot  = 309 # √ (CP437 251)

    # Returns the primary Unicode representation for this ASCII or extended piece
    def char : Char
      case self
      when Space                then ' '
      when Exclamation          then '!'
      when DoubleQuote          then '"'
      when Hash                 then '#'
      when Dollar               then '$'
      when Percent              then '%'
      when Ampersand            then '&'
      when SingleQuote          then '\''
      when ParenOpen            then '('
      when ParenClose           then ')'
      when Asterisk             then '*'
      when Plus                 then '+'
      when Comma                then ','
      when Hyphen               then '-'
      when Period               then '.'
      when Slash                then '/'
      when Digit0               then '0'
      when Digit1               then '1'
      when Digit2               then '2'
      when Digit3               then '3'
      when Digit4               then '4'
      when Digit5               then '5'
      when Digit6               then '6'
      when Digit7               then '7'
      when Digit8               then '8'
      when Digit9               then '9'
      when Colon                then ':'
      when Semicolon            then ';'
      when Less                 then '<'
      when Equal                then '='
      when Greater              then '>'
      when Question             then '?'
      when At                   then '@'
      when BracketOpen          then '['
      when Backslash            then '\\'
      when BracketClose         then ']'
      when Caret                then '^'
      when Underscore           then '_'
      when Backtick             then '`'
      when BraceOpen            then '{'
      when Pipe                 then '|'
      when BraceClose           then '}'
      when Tilde                then '~'
      when SmileyFace           then '☺'
      when SmileyInverse        then '☻'
      when Heart                then '♥'
      when Diamond              then '♦'
      when Club                 then '♣'
      when Spade                then '♠'
      when Bullet               then '•'
      when InverseBullet        then '◘'
      when CircleOpen           then '○'
      when CircleInverse        then '◙'
      when MusicalNote          then '♪'
      when MusicalNotes         then '♫'
      when Sun                  then '☼'
      when ArrowRightFill       then '►'
      when ArrowLeftFill        then '◄'
      when ArrowUpDown          then '↕'
      when DoubleExclamation    then '‼'
      when Paragraph            then '¶'
      when Section              then '§'
      when RectangleFill        then '▬'
      when ArrowUpDownBase      then '↨'
      when ArrowUp              then '↑'
      when ArrowDown            then '↓'
      when ArrowRight           then '→'
      when ArrowLeft            then '←'
      when RightAngle           then '∟'
      when LeftRightArrow       then '↔'
      when TriangleUp           then '▲'
      when TriangleDown         then '▼'
      when LightShade           then '░'
      when MediumShade          then '▒'
      when DarkShade            then '▓'
      when BoxVertical          then '│'
      when BoxRightTee          then '┤'
      when BoxVerticalDouble    then '║'
      when BoxTopRightDouble    then '╗'
      when BoxBottomRightDouble then '╝'
      when BoxTopRight          then '┐'
      when BoxBottomLeft        then '└'
      when BoxBottomTee         then '┴'
      when BoxTopTee            then '┬'
      when BoxLeftTee           then '├'
      when BoxHorizontal        then '─'
      when BoxCross             then '┼'
      when BoxBottomRight       then '┘'
      when BoxTopLeft           then '┌'
      when BoxFullBlock         then '█'
      when BoxBottomHalf        then '▄'
      when BoxLeftHalf          then '▌'
      when BoxRightHalf         then '▐'
      when BoxTopHalf           then '▀'
      when Degree               then '°'
      when BulletSmall          then '∙'
      when SquareRoot           then '√'
      else
        val = to_i
        if val >= 0 && val <= 127
          val.chr
        else
          '?'
        end
      end
    end

    # Returns the strict 7-bit ASCII fallback for terminals with limited font support
    def ascii_fallback : Char
      case self
      when SmileyFace, SmileyInverse          then '@'
      when Heart, Diamond, Club, Spade        then '*'
      when Bullet, BulletSmall, InverseBullet then '*'
      when CircleOpen, CircleInverse          then 'o'
      when MusicalNote, MusicalNotes          then '#'
      when Sun                                then '*'
      when ArrowRightFill, ArrowRight         then '>'
      when ArrowLeftFill, ArrowLeft           then '<'
      when ArrowUpDown, ArrowUpDownBase       then '|'
      when DoubleExclamation                  then '!'
      when Paragraph, Section                 then '$'
      when RectangleFill                      then '-'
      when ArrowUp, TriangleUp                then '^'
      when ArrowDown, TriangleDown            then 'v'
      when RightAngle                         then '+'
      when LeftRightArrow                     then '-'
      when LightShade, MediumShade, DarkShade then '.'
      when BoxVertical, BoxVerticalDouble     then '|'
      when BoxHorizontal                      then '-'
      when BoxTopLeft, BoxTopRight, BoxBottomLeft, BoxBottomRight,
           BoxLeftTee, BoxRightTee, BoxTopTee, BoxBottomTee, BoxCross,
           BoxTopRightDouble, BoxBottomRightDouble then '+'
      when BoxFullBlock, BoxBottomHalf, BoxLeftHalf, BoxRightHalf, BoxTopHalf then '#'
      when Degree                                                             then 'o'
      when SquareRoot                                                         then 'v'
      else
        val = to_i
        if val >= 0 && val <= 127
          val.chr
        else
          '?'
        end
      end
    end

    def to_s(io : IO) : Nil
      io << char
    end

    # Finds an AsciiCode entry by case-insensitive name or alias
    def self.find?(name : String) : AsciiCode?
      clean = name.downcase.gsub(/[^a-z0-9]/, "")
      AsciiCode.each do |code|
        code_name = code.to_s.downcase.gsub(/[^a-z0-9]/, "")
        return code if code_name == clean
      end
      nil
    end

    # Resolves an AsciiCode from a Char
    def self.from_char?(ch : Char) : AsciiCode?
      AsciiCode.each do |code|
        return code if code.char == ch
      end
      nil
    end
  end

  # Module alias for convenient syntax: Opal::Ascii::BoxVertical, etc.
  alias Ascii = AsciiCode
end
