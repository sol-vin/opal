require "./style/color"
require "./style/visual_width"
require "./style/border"
require "./style/style"
require "./style/layout"
require "./style/theme"
require "./style/animation"

module Opal
  # Convenience helper to create a new Style instance
  def self.style : Style
    Style.new
  end

  # Returns the current active Theme
  def self.theme : Theme
    Theme.current
  end

  # Sets the current active Theme by symbol, string, or Theme instance
  def self.theme=(theme : Theme | Symbol | String) : Theme
    Theme.current = theme
  end
end
