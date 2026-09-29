require "spec"
require "../src/opal"

def create_mock_driver(width = 80, height = 24) : Opal::Terminal::MockDriver
  Opal::Terminal::MockDriver.new(width, height)
end
