require "./cli/option"
require "./cli/argument"
require "./cli/context"
require "./cli/help"
require "./cli/command"
require "./cli/parser"
require "./cli/completion"
require "./cli/app"

module Opal
  # Convenience DSL to define and configure a CLI application.
  def self.cli(name : String, version : String = "0.1.0", &block : CLI::App -> Nil) : CLI::App
    app = CLI::App.new(name, version)
    block.call(app)
    app
  end
end
