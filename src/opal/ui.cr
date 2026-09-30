require "./ui/rect"
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
require "./ui/components/split_view"
require "./ui/components/code_view"
require "./ui/components/tabs"
require "./ui/components/hex_viewer"
require "./ui/components/file_dialog"
require "./ui/components/color_picker"
require "./ui/components/color_picker_3d"
require "./ui/components/pie_chart"
require "./ui/components/line_graph"
require "./ui/components/ascii_image"
require "./ui/components/button"
require "./ui/components/dropdown"
require "./ui/components/scrollbar"
require "./ui/components/window"
require "./ui/components/canvas_2d"
require "./ui/components/mesh_3d"
require "./ui/dsl"

module Opal
  # Convenience shortcut to render a declarative UI tree
  def self.render_ui(width : Int32 = 80, height : Int32 = 24, &block : UI::Builder -> Nil) : String
    UI.render(width, height, &block)
  end
end
