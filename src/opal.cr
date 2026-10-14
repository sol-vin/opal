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
require "./opal/testing"

# Opal: Next-generation TUI and CLI DSL framework for Crystal.
# Unifies The Elm Architecture (Bubbletea), Declarative Layout (Ink),
# and Low-Level Double-Buffered Terminal Diffing (Blessed).
module Opal
  # Top-level DSL mixin allowing any class or namespace to write Opal DSL directly
  module DSL
    include UI::DSL
    alias SplitPane = UI::SplitView
    alias SplitBuilder = UI::SplitBuilder
  end

  # Creates a clickable OSC 8 hyperlink for modern terminals.
  def self.hyperlink(text : String, url : String, id : String? = nil) : String
    Terminal::OSC.hyperlink(text, url, id)
  end

  # Declarative `link(url, label)` OSC 8 terminal hyperlink helper.
  # If `label` is omitted, defaults to `url`. Also supports `(label, url)` if the second argument is a URI.
  def self.link(url : String, label : String? = nil, id : String? = nil) : String
    Terminal::OSC.link(url, label, id)
  end

  # Creates an OSC 8 hyperlink for a GitHub repository, RFC/Discussion, Issue, or PR.
  def self.github_link(
    repo : String,
    kind : Symbol | String,
    number : Int32 | String,
    label : String? = nil,
    id : String? = nil,
  ) : String
    Terminal::OSC.github_link(repo, kind, number, label, id)
  end

  # Creates an OSC 8 hyperlink for a GitHub RFC Discussion (`RFC #XX`).
  def self.rfc_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
    Terminal::OSC.rfc_link(repo, number, label, id)
  end

  # Creates an OSC 8 hyperlink for a GitHub Discussion (`Discussion #XX`).
  def self.discussion_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
    Terminal::OSC.discussion_link(repo, number, label, id)
  end

  # Creates an OSC 8 hyperlink for a GitHub Issue (`Issue #XX`).
  def self.issue_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
    Terminal::OSC.issue_link(repo, number, label, id)
  end

  # Creates an OSC 8 hyperlink for a GitHub Pull Request (`PR #XX`).
  def self.pr_link(repo : String, number : Int32 | String, label : String? = nil, id : String? = nil) : String
    Terminal::OSC.pr_link(repo, number, label, id)
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
