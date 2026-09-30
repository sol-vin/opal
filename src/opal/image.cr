require "./image/pixel_buffer"

module Opal
  # Creates a new PixelBuffer with specified width, height, and optional default color.
  def self.pixel_buffer(width : Int32, height : Int32, default_color : Color = Color.none) : Image::PixelBuffer
    Image::PixelBuffer.new(width, height, default_color)
  end
end
