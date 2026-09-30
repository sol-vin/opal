require "./tea/msg"
require "./tea/cmd"
require "./tea/model"
require "./tea/program"

module Opal
  # Convenience helper to instantiate and run a TEA Program
  def self.run_tea(
    model : TEA::Model,
    driver : Terminal::Driver? = nil,
    alt_screen : Bool = true,
    diff_render : Bool = true,
  ) : TEA::Model
    TEA::Program.new(
      model,
      driver: driver,
      alt_screen: alt_screen,
      diff_render: diff_render,
    ).run
  end
end
