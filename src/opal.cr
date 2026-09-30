require "./opal/version"
require "./opal/terminal"
require "./opal/style"
require "./opal/cli"
require "./opal/prompt"
require "./opal/input"
require "./opal/tea"
require "./opal/ui"
require "./opal/form"
require "./opal/shader"

# Opal: Next-generation TUI and CLI DSL framework for Crystal.
# Unifies The Elm Architecture (Bubbletea), Declarative Layout (Ink),
# and Low-Level Double-Buffered Terminal Diffing (Blessed).
module Opal
  # Creates a clickable OSC 8 hyperlink for modern terminals.
  def self.hyperlink(text : String, url : String, id : String? = nil) : String
    Terminal::OSC.hyperlink(text, url, id)
  end

  # Alias for hyperlink
  def self.link(text : String, url : String, id : String? = nil) : String
    Terminal::OSC.hyperlink(text, url, id)
  end

  # Copies text to the host system clipboard via OSC 52.
  def self.copy_to_clipboard(text : String, io : IO = STDOUT) : Nil
    Terminal::OSC.copy_to_clipboard(text, io)
  end
end
