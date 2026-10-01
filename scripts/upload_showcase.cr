require "../src/opal/asciicast"

install_id = Opal::Asciicast::Uploader.get_or_create_install_id
puts "Install ID: #{install_id}"
puts "Uploading demos/06_opal_tui_showcase.cast..."
result = Opal::Asciicast::Uploader.upload_file("demos/06_opal_tui_showcase.cast", install_id, verbose: true)
puts "Result: #{result}"
