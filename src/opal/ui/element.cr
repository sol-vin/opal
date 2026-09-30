require "./buffer"
require "./themable"

module Opal
  module UI
    # Base class for all visual components in the declarative UI hierarchy.
    abstract class Element
      include Themable

      abstract def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
      abstract def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}
    end
  end
end

require "./input_hookable"
require "./control"
require "./engine"
