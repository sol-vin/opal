require "spec"
require "../src/opal"

include Opal::Testing::SpecHelper

def create_mock_driver(width = 80, height = 24) : Opal::Terminal::MockDriver
  Opal::Terminal::MockDriver.new(width, height)
end

