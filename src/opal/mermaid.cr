require "./ui"
require "./mermaid/ast"
require "./mermaid/parser"
require "./mermaid/renderer"
require "./mermaid/viewer"

module Opal
  module UI
    module DSL
      # Declarative DSL helper to construct a Mermaid diagram viewer
      def mermaid_viewer(
        diagram_text : String,
        scrollable : Bool = true,
        auto_scroll : Bool = false,
        scroll_speed : Float64 = 1.0,
        border : Border = Border.rounded
      ) : MermaidViewer
        viewer = MermaidViewer.new(
          diagram_text,
          scrollable: scrollable,
          auto_scroll: auto_scroll,
          scroll_speed: scroll_speed,
          border: border
        )
        add_element(viewer)
        viewer
      end

      # Declarative DSL helper for async mermaid viewer with background computation
      def async_mermaid_viewer(label : String = "Generating diagram...", &block : -> String) : AsyncMermaidViewer
        viewer = AsyncMermaidViewer.new(label, &block)
        add_element(viewer)
        viewer
      end
    end
  end
end
