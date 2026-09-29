require "./msg"
require "./cmd"

module Opal
  module TEA
    # Core Model interface representing the state, update logic, and view in The Elm Architecture.
    module Model
      # Returns initial commands to execute upon application startup.
      abstract def init : Cmd

      # Updates the model state based on an incoming message, returning the new model and optional command.
      abstract def update(msg : Msg) : {Model, Cmd}

      # Renders the current state as a formatted terminal string.
      abstract def view : String
    end
  end
end
