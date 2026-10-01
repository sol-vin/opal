require "./terminal/screen"
require "./terminal/ansi_parser"
require "./terminal/driver"
require "./terminal/raw_mode"
require "./terminal/mock"
require "./terminal/info"
require "./terminal/osc"
require "./terminal/ascii"
{% if flag?(:windows) %}
  require "./terminal/windows"
{% else %}
  require "./terminal/posix"
{% end %}

module Opal
  module Terminal
    # Returns the standard platform-specific terminal driver.
    def self.default_driver(output : IO = STDOUT, input : IO = STDIN) : Driver
      {% if flag?(:windows) %}
        WindowsDriver.new(output: output, input: input)
      {% else %}
        PosixDriver.new(output: output, input: input)
      {% end %}
    end
  end
end
