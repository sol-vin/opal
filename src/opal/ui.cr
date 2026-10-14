require "./ui/rect"
require "./core/split_layout"
require "./ui/cell"
require "./ui/buffer"
require "./ui/layer"
require "./ui/layer_stack"
require "./ui/diff_renderer"

require "./ui/element"
require "./ui/input_hookable"
require "./ui/control"
require "./ui/engine"
require "./ui/components/text"
require "./ui/components/badge"
require "./ui/components/rule"
require "./ui/components/stack"
require "./ui/components/box"
require "./ui/components/table"
require "./ui/components/viewport"
require "./ui/components/sparkline"
require "./ui/components/barchart"
require "./ui/components/gauge"
require "./ui/components/tree"
require "./ui/components/modal"
require "./ui/components/toast"
require "./ui/components/filter_list"
require "./ui/components/command_palette"
require "./ui/components/split_view"
require "./ui/components/code_view"
require "./ui/components/tabs"
require "./ui/components/hex_viewer"
require "./ui/components/file_dialog"
require "./ui/components/target_selector_2d"
require "./ui/components/curve_editor"
require "./ui/components/equation_viewer"
require "./ui/components/character_grid"
require "./ui/components/color_picker"
require "./ui/components/color_picker_3d"
require "./ui/components/palette"
require "./ui/components/pie_chart"
require "./ui/components/line_graph"
require "./ui/components/ascii_image"
require "./ui/components/button"
require "./ui/components/dropdown"
require "./ui/components/scrollbar"
require "./ui/components/window"
require "./ui/components/canvas_2d"
require "./ui/components/mesh_3d"
require "./ui/components/switch"
require "./ui/components/checkbox"
require "./ui/components/slider"
require "./ui/components/radio_set"
require "./ui/components/collapsible"
require "./ui/components/digits"
require "./ui/components/rich_log"
require "./ui/components/loading_indicator"
require "./ui/components/header"
require "./ui/components/footer"
require "./ui/components/placeholder"
require "./ui/components/content_switcher"
require "./ui/components/binary_metrics"
require "./ui/components/input_remapper"
require "./ui/components/link"
require "./ui/layouts/dock"
require "./ui/layouts/grid"
require "./ui/screen"
require "./ui/screen_stack"
require "./ui/query"
require "./ui/dsl"

module Opal
  # Convenience shortcut to render a declarative UI tree
  def self.render_ui(width : Int32 = 80, height : Int32 = 24, with_ansi : Bool = false, &) : String
    UI.render(width, height, with_ansi: with_ansi) { |b| with b yield b }
  end

  # Convenience shortcut to render a declarative UI tree with ANSI colors and OSC 8 hyperlinks
  def self.render_ui_ansi(width : Int32 = 80, height : Int32 = 24, &) : String
    UI.render_ansi(width, height) { |b| with b yield b }
  end

  # Declarative top-level builder for a Two-Tier `Opal::UI::SplitView` (`Opal::DSL::SplitPane`)
  # backed by `Opal::Core::SplitLayout`.
  def self.split_pane(
    direction : UI::SplitDirection | Core::SplitOrientation | Symbol | String = UI::SplitDirection::Horizontal,
    ratio : Float64? = 0.5,
    first_size : Int32? = nil,
    second_size : Int32? = nil,
    min_first_size : Int32? = nil,
    max_first_size : Int32? = nil,
    min_second_size : Int32? = nil,
    max_second_size : Int32? = nil,
    separator : Char? = nil,
    separator_fg : Color | Symbol | String = Color.none,
    focused_pane : Symbol | Int32 | String = :first,
    show_separator : Bool = true,
    resize_step : Float64 = 0.05,
    &
  ) : UI::SplitView
    UI.split_pane(
      direction: direction,
      ratio: ratio,
      first_size: first_size,
      second_size: second_size,
      min_first_size: min_first_size,
      max_first_size: max_first_size,
      min_second_size: min_second_size,
      max_second_size: max_second_size,
      separator: separator,
      separator_fg: separator_fg,
      focused_pane: focused_pane,
      show_separator: show_separator,
      resize_step: resize_step
    ) { |sb| with sb yield sb }
  end

  # Declarative top-level builder for a horizontal `SplitView`.
  def self.hsplit(
    ratio : Float64? = 0.5,
    first_width : Int32? = nil,
    second_width : Int32? = nil,
    min_first_width : Int32? = nil,
    max_first_width : Int32? = nil,
    min_second_width : Int32? = nil,
    max_second_width : Int32? = nil,
    separator : Char? = nil,
    separator_fg : Color | Symbol | String = Color.none,
    focused_pane : Symbol | Int32 | String = :first,
    show_separator : Bool = true,
    &
  ) : UI::SplitView
    UI.hsplit(
      ratio: ratio,
      first_width: first_width,
      second_width: second_width,
      min_first_width: min_first_width,
      max_first_width: max_first_width,
      min_second_width: min_second_width,
      max_second_width: max_second_width,
      separator: separator,
      separator_fg: separator_fg,
      focused_pane: focused_pane,
      show_separator: show_separator
    ) { |sb| with sb yield sb }
  end

  # Declarative top-level builder for a vertical `SplitView`.
  def self.vsplit(
    ratio : Float64? = 0.5,
    first_height : Int32? = nil,
    second_height : Int32? = nil,
    min_first_height : Int32? = nil,
    max_first_height : Int32? = nil,
    min_second_height : Int32? = nil,
    max_second_height : Int32? = nil,
    separator : Char? = nil,
    separator_fg : Color | Symbol | String = Color.none,
    focused_pane : Symbol | Int32 | String = :first,
    show_separator : Bool = true,
    &
  ) : UI::SplitView
    UI.vsplit(
      ratio: ratio,
      first_height: first_height,
      second_height: second_height,
      min_first_height: min_first_height,
      max_first_height: max_first_height,
      min_second_height: min_second_height,
      max_second_height: max_second_height,
      separator: separator,
      separator_fg: separator_fg,
      focused_pane: focused_pane,
      show_separator: show_separator
    ) { |sb| with sb yield sb }
  end

  # Convenience constructor for a standalone Tier-1 `Opal::Core::SplitLayout` constraint solver.
  def self.split_layout(
    orientation : Core::SplitOrientation | UI::SplitDirection | Symbol | String = Core::SplitOrientation::Horizontal,
    ratio : Float64? = 0.5,
    first_size : Int32? = nil,
    second_size : Int32? = nil,
    min_first_size : Int32? = nil,
    max_first_size : Int32? = nil,
    min_second_size : Int32? = nil,
    max_second_size : Int32? = nil,
    focused_pane : Symbol | Int32 | String = :first,
    show_separator : Bool = true,
    separator_size : Int32 = 1,
    resize_step : Float64 = 0.05,
  ) : Core::SplitLayout
    Core::SplitLayout.new(
      orientation: orientation,
      ratio: ratio,
      first_size: first_size,
      second_size: second_size,
      min_first_size: min_first_size,
      max_first_size: max_first_size,
      min_second_size: min_second_size,
      max_second_size: max_second_size,
      focused_pane: focused_pane,
      show_separator: show_separator,
      separator_size: separator_size,
      resize_step: resize_step
    )
  end
end
