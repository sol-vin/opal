require "../style/theme"
require "../style/color"
require "../style/border"

module Opal
  module UI
    # Module mixed into Elements and Controls allowing per-instance theme binding,
    # dynamic theme fallback, and fluent styling blocks.
    module Themable
      # Optional local theme override for this component instance
      property theme : Theme? = nil

      # Returns the effective theme: either this component's local theme or global Theme.current
      def current_theme : Theme
        @theme || Theme.current
      end

      # Assigns a local theme to this component
      def with_theme(new_theme : Theme | Symbol | String) : self
        @theme = case new_theme
                 when Theme
                   new_theme
                 else
                   Theme.get(new_theme)
                 end
        self
      end

      # Yields self to a block for fluent styling/theme value manipulation
      def style(&block : self -> Nil) : self
        block.call(self)
        self
      end
    end
  end
end
