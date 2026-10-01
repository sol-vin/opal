require "./ui"
require "./html/parser"
require "./html/browser"

module Opal
  module UI
    module DSL
      # Declarative DSL helper to construct a TUI HTML web browser component
      def html_browser(initial_url : String = "about:home", enable_osc8 : Bool = true, &block : HTMLBrowser -> Nil) : HTMLBrowser
        browser = HTMLBrowser.new(initial_url, enable_osc8: enable_osc8)
        yield browser
        add_element(browser)
        browser
      end

      def html_browser(initial_url : String = "about:home", enable_osc8 : Bool = true) : HTMLBrowser
        browser = HTMLBrowser.new(initial_url, enable_osc8: enable_osc8)
        add_element(browser)
        browser
      end
    end
  end
end
