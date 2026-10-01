module Opal
  # Comprehensive catalog and store of Unicode terminal characters, block shades,
  # directional indicators, gradients, and animated spinners.
  module Glyphs
    # --- Block Shading Characters ---
    Empty       = ' '
    LightShade  = '░'
    MediumShade = '▒'
    DarkShade   = '▓'
    FullBlock   = '█'

    # Short aliases for quick typing
    Light  = LightShade
    Medium = MediumShade
    Dark   = DarkShade
    Full   = FullBlock

    # --- Half Blocks ---
    UpperHalf = '▀'
    LowerHalf = '▄'
    LeftHalf  = '▌'
    RightHalf = '▐'

    # --- Fractional Horizontal Blocks (1/8th increments: 0.125 to 1.0) ---
    Bar1 = '▏'
    Bar2 = '▎'
    Bar3 = '▍'
    Bar4 = '▌'
    Bar5 = '▋'
    Bar6 = '▊'
    Bar7 = '▉'
    Bar8 = '█'

    # --- Fractional Vertical Blocks (1/8th increments: 0.125 to 1.0) ---
    VBar1 = ' '
    VBar2 = '▂'
    VBar3 = '▃'
    VBar4 = '▄'
    VBar5 = '▅'
    VBar6 = '▆'
    VBar7 = '▇'
    VBar8 = '█'

    # --- Quadrants ---
    QuadrantUL = '▘'
    QuadrantUR = '▝'
    QuadrantLL = '▖'
    QuadrantLR = '▗'

    # --- Directionals: Triangles / Pointers ---
    TriangleUp    = '▲'
    TriangleDown  = '▼'
    TriangleLeft  = '◀'
    TriangleRight = '▶'

    TriangleUpSmall    = '▴'
    TriangleDownSmall  = '▾'
    TriangleLeftSmall  = '◂'
    TriangleRightSmall = '▸'

    TriangleUpOutline    = '△'
    TriangleDownOutline  = '▽'
    TriangleLeftOutline  = '◁'
    TriangleRightOutline = '▷'

    # Short pointer aliases
    Up    = TriangleUp
    Down  = TriangleDown
    Left  = TriangleLeft
    Right = TriangleRight

    # --- Directionals: Simple Arrows ---
    ArrowUp    = '↑'
    ArrowDown  = '↓'
    ArrowLeft  = '←'
    ArrowRight = '→'

    ArrowUpRight   = '↗'
    ArrowDownRight = '↘'
    ArrowDownLeft  = '↙'
    ArrowUpLeft    = '↖'

    # Double Arrows
    DblArrowUp    = '⇑'
    DblArrowDown  = '⇓'
    DblArrowLeft  = '⇐'
    DblArrowRight = '⇒'

    # Heavy / Bold Arrows
    HeavyArrowUp    = '⬆'
    HeavyArrowDown  = '⬇'
    HeavyArrowLeft  = '⬅'
    HeavyArrowRight = '➡'

    # Chevrons
    ChevronUp    = '︿'
    ChevronDown  = '﹀'
    ChevronLeft  = '〈'
    ChevronRight = '〉'

    # --- Spinning & Radial Glyphs ---
    HalfCircleLeft   = '◐'
    HalfCircleTop    = '◓'
    HalfCircleRight  = '◑'
    HalfCircleBottom = '◒'

    CircleEmpty        = '○'
    CircleQuarter      = '◔'
    CircleHalf         = '◐'
    CircleThreeQuarter = '◕'
    CircleFull         = '●'

    # --- Status, Markers & Bullets ---
    Bullet       = '•'
    SmallBullet  = '·'
    Diamond      = '◆'
    DiamondEmpty = '◇'
    Check        = '✓'
    Cross        = '✗'
    Gear         = '⚙'
    Star         = '★'
    StarEmpty    = '☆'
    Warning      = '⚠'

    # =========================================================================
    # Collections & Gradients
    # =========================================================================

    # 5-step Unicode shade density gradient (0.0 to 1.0)
    Shades = [' ', LightShade, MediumShade, DarkShade, FullBlock]

    # Inverted 5-step shade density gradient
    ShadesReversed = [FullBlock, DarkShade, MediumShade, LightShade, ' ']

    # 10-step standard ASCII ramp
    AsciiRamp = [' ', '.', ':', '-', '=', '+', '*', '%', '@', '#']

    # 9-step horizontal block ramp (0 to 8 eighths)
    HorizontalBlocks = [' ', Bar1, Bar2, Bar3, Bar4, Bar5, Bar6, Bar7, Bar8]

    # 9-step vertical block ramp (0 to 8 eighths)
    VerticalBlocks = [' ', VBar1, VBar2, VBar3, VBar4, VBar5, VBar6, VBar7, VBar8]

    # 5-step radial circular fill gradient
    Circles = [CircleEmpty, CircleQuarter, CircleHalf, CircleThreeQuarter, CircleFull]

    # 4-step Braille dot density gradient
    BrailleDots = ['⣀', '⣤', '⣶', '⣿']

    # =========================================================================
    # Directional & Animated Spinner Series
    # =========================================================================

    # 4-frame rotating half-circle spinner
    HalfCircles = [HalfCircleLeft, HalfCircleTop, HalfCircleRight, HalfCircleBottom]

    # 4-frame rotating quadrant corner spinner
    QuadrantSpin = ['◴', '◷', '◶', '◵']

    # 4-frame smooth arc spinner
    ArcSpin = ['◜', '◝', '◞', '◟']

    # 8-frame rotating arrow compass spinner
    ArrowSpin = [ArrowLeft, ArrowUpLeft, ArrowUp, ArrowUpRight, ArrowRight, ArrowDownRight, ArrowDown, ArrowDownLeft]

    # 4-frame classic ASCII pipe spinner
    PipeSpin = ['|', '/', '-', '\\']

    # 10-frame smooth Braille dots spinner
    BrailleSpin = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']

    # 12-frame clock face progression
    ClockSpin = ["🕐", "🕑", "🕒", "🕓", "🕔", "🕕", "🕖", "🕗", "🕘", "🕙", "🕚", "🕛"]

    # 8-frame lunar phase progression
    MoonSpin = ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"]

    # =========================================================================
    # Convenience Query & Interpolation Helpers
    # =========================================================================

    # Maps a normalized weight (0.0..1.0) to a shade character
    def self.shade(weight : Float64) : Char
      idx = (weight.clamp(0.0, 1.0) * (Shades.size - 1)).round.to_i
      Shades[idx]
    end

    # Maps a normalized weight (0.0..1.0) to an 1/8th horizontal fractional bar
    def self.h_bar(weight : Float64) : Char
      idx = (weight.clamp(0.0, 1.0) * (HorizontalBlocks.size - 1)).round.to_i
      HorizontalBlocks[idx]
    end

    # Maps a normalized weight (0.0..1.0) to an 1/8th vertical fractional bar
    def self.v_bar(weight : Float64) : Char
      idx = (weight.clamp(0.0, 1.0) * (VerticalBlocks.size - 1)).round.to_i
      VerticalBlocks[idx]
    end

    # Maps a normalized weight (0.0..1.0) to a circle fill glyph
    def self.circle(weight : Float64) : Char
      idx = (weight.clamp(0.0, 1.0) * (Circles.size - 1)).round.to_i
      Circles[idx]
    end

    # Returns an arrow glyph for a given directional symbol
    def self.arrow(dir : Symbol) : Char
      case dir
      when :up, :north      then ArrowUp
      when :down, :south    then ArrowDown
      when :left, :west     then ArrowLeft
      when :right, :east    then ArrowRight
      when :up_right, :ne   then ArrowUpRight
      when :down_right, :se then ArrowDownRight
      when :down_left, :sw  then ArrowDownLeft
      when :up_left, :nw    then ArrowUpLeft
      else                       ArrowRight
      end
    end

    # Returns a triangle pointer for a given directional symbol
    def self.triangle(dir : Symbol, small : Bool = false) : Char
      if small
        case dir
        when :up    then TriangleUpSmall
        when :down  then TriangleDownSmall
        when :left  then TriangleLeftSmall
        when :right then TriangleRightSmall
        else             TriangleRightSmall
        end
      else
        case dir
        when :up    then TriangleUp
        when :down  then TriangleDown
        when :left  then TriangleLeft
        when :right then TriangleRight
        else             TriangleRight
        end
      end
    end

    # Returns the character/string for a spinner style at a given animation frame
    def self.spinner_frame(style : Symbol, frame : Int32) : String
      frames = case style
               when :half_circle, :half_circles then HalfCircles
               when :arc, :arcs                 then ArcSpin
               when :quadrant                   then QuadrantSpin
               when :arrows, :arrow             then ArrowSpin
               when :pipe, :pipes, :line        then PipeSpin
               when :braille, :dots             then BrailleSpin
               when :clock, :clocks             then ClockSpin
               when :moon, :moons               then MoonSpin
               else                                  BrailleSpin
               end

      item = frames[frame % frames.size]
      item.is_a?(Char) ? item.to_s : item
    end
  end

  # Developer-friendly alias for Opal::Glyphs
  alias Chars = Glyphs
end
