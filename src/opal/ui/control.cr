require "./element"
require "./input_hookable"

module Opal
  module UI
    # Abstract base class for all interactive, focusable UI components.
    # Integrates with `InputHookable` to support custom per-control input hooks,
    # default input lifecycles, and code puppeting.
    abstract class Control < Element
      include InputHookable

      def initialize
        setup_default_inputs
      end
    end
  end
end
