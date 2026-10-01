require "./opal/version"
require "./opal/terminal"
require "./opal/style"
require "./opal/cli"
require "./opal/prompt"
require "./opal/input"
require "./opal/tea"
require "./opal/image"
require "./opal/ui"
require "./opal/form"
require "./opal/shader"
require "./opal/animation/animator"
require "./opal/async/worker"
require "./opal/clipboard"

# Opal: Next-generation TUI and CLI DSL framework for Crystal.
# Unifies The Elm Architecture (Bubbletea), Declarative Layout (Ink),
# and Low-Level Double-Buffered Terminal Diffing (Blessed).
module Opal
  # Top-level DSL mixin allowing any class or namespace to write Opal DSL directly
  module DSL
    include UI::DSL
  end

  # Creates a clickable OSC 8 hyperlink for modern terminals.
  def self.hyperlink(text : String, url : String, id : String? = nil) : String
    Terminal::OSC.hyperlink(text, url, id)
  end

  # Alias for hyperlink
  def self.link(text : String, url : String, id : String? = nil) : String
    Terminal::OSC.hyperlink(text, url, id)
  end

  # Access to the universal clipboard subsystem.
  def self.clipboard : Clipboard.class
    Clipboard
  end

  # Copies text to the system clipboard using OSC 52 and native OS tools.
  def self.copy_to_clipboard(text : String, io : IO = STDOUT) : Bool
    Clipboard.copy(text, io)
  end
end
