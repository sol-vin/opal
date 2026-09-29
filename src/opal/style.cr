require "./style/color"
require "./style/visual_width"
require "./style/border"
require "./style/style"
require "./style/layout"

module Opal
  # Convenience helper to create a new Style instance
  def self.style : Style
    Style.new
  end
end
