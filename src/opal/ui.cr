require "./ui/cell"
require "./ui/buffer"
require "./ui/diff_renderer"
require "./ui/element"
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
require "./ui/dsl"

module Opal
  # Convenience shortcut to render a declarative UI tree
  def self.render_ui(width : Int32 = 80, height : Int32 = 24, &block : UI::Builder -> Nil) : String
    UI.render(width, height, &block)
  end
end
