require "./shader/context"
require "./shader/pass"
require "./shader/presets"
require "./shader/pipeline"

module Opal
  module Shader
    # Creates and configures a multi-pass text shader pipeline via a block DSL.
    def self.pipeline(&block : Pipeline -> Nil) : Pipeline
      pipe = Pipeline.new
      block.call(pipe)
      pipe
    end
  end

  # Shortcut to construct a shader pipeline.
  def self.shader_pipeline(&block : Shader::Pipeline -> Nil) : Shader::Pipeline
    Shader.pipeline(&block)
  end
end
