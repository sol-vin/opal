require "./spec_helper"
require "../src/opal/asciicast/asciinema"

describe "Opal VCR Recording & Playback System" do
  describe "Aliases and Optional Require" do
    it "exposes Opal::VCR and Opal::Asciinema::VCR" do
      Opal::VCR.should eq(Opal::Asciicast::VCR)
      Opal::Asciinema::VCR.should eq(Opal::Asciicast::VCR)
    end
  end

  describe "Singleton VCR Recording" do
    it "records sessions using block syntax with automatic save" do
      temp_cast = File.tempfile("vcr_block", ".cast")
      cast_path = temp_cast.path
      temp_cast.close

      Opal::VCR.record(cast_path, width: 30, height: 6, title: "Singleton Block Test") do |vcr|
        vcr.recording?.should be_true
        buf1 = Opal::UI::Buffer.new(30, 6)
        buf1.put_string(0, 0, "Scene 1")
        vcr.capture(buf1, advance: 0.1)

        vcr.wait_frames(2, delay_per_frame: 0.05)

        buf2 = Opal::UI::Buffer.new(30, 6)
        buf2.put_string(0, 0, "Scene 2")
        vcr.capture(buf2, advance: 0.1)
      end

      Opal::VCR.recording?.should be_false
      File.exists?(cast_path).should be_true

      content = File.read(cast_path)
      content.should contain("Singleton Block Test")
      content.should contain("Scene 1")
      content.should contain("Scene 2")

      File.delete(cast_path) if File.exists?(cast_path)
    end

    it "records sessions using imperative step-by-step methods" do
      temp_cast = File.tempfile("vcr_imperative", ".cast")
      cast_path = temp_cast.path
      temp_cast.close

      Opal::VCR.record(cast_path, width: 25, height: 5, title: "Imperative VCR")
      Opal::VCR.recording?.should be_true

      buf = Opal::UI::Buffer.new(25, 5)
      buf.put_string(0, 0, "Frame Alpha")
      Opal::VCR.capture(buf, advance: 0.1)

      Opal::VCR.pause
      Opal::VCR.paused?.should be_true

      buf_skip = Opal::UI::Buffer.new(25, 5)
      buf_skip.put_string(0, 0, "Ignored In Pause")
      Opal::VCR.capture(buf_skip, advance: 0.1)

      Opal::VCR.resume
      Opal::VCR.paused?.should be_false

      buf.put_string(0, 1, "Frame Beta")
      Opal::VCR.capture(buf, advance: 0.1)

      Opal::VCR.hold(0.2)
      Opal::VCR.stop
      Opal::VCR.save

      content = File.read(cast_path)
      content.should contain("Frame Alpha")
      content.should_not contain("Ignored In Pause")
      content.should contain("Frame Beta")

      File.delete(cast_path) if File.exists?(cast_path)
    end
  end

  describe "Instanced VCR Cassette Decks" do
    it "allows concurrent independent VCR instances" do
      deck_a = Opal::VCR.new
      deck_b = Opal::VCR.new

      temp_a = File.tempfile("deck_a", ".cast")
      temp_b = File.tempfile("deck_b", ".cast")
      path_a = temp_a.path
      path_b = temp_b.path
      temp_a.close
      temp_b.close

      deck_a.record(path_a, width: 20, height: 4, title: "Deck A")
      deck_b.record(path_b, width: 20, height: 4, title: "Deck B")

      buf_a = Opal::UI::Buffer.new(20, 4)
      buf_a.put_string(0, 0, "Tape A Content")
      deck_a.capture(buf_a, advance: 0.1)

      buf_b = Opal::UI::Buffer.new(20, 4)
      buf_b.put_string(0, 0, "Tape B Content")
      deck_b.capture(buf_b, advance: 0.1)

      deck_a.stop.save
      deck_b.stop.save

      content_a = File.read(path_a)
      content_b = File.read(path_b)

      content_a.should contain("Tape A Content")
      content_a.should_not contain("Tape B Content")

      content_b.should contain("Tape B Content")
      content_b.should_not contain("Tape A Content")

      File.delete(path_a) if File.exists?(path_a)
      File.delete(path_b) if File.exists?(path_b)
    end
  end

  describe "VCR Playback and Frame-by-Frame Stepping" do
    sample_cast = <<-CAST
      {"version":2,"width":20,"height":4,"timestamp":1700000000,"title":"Playback Test"}
      [0.0, "o", "\\u001b[H\\u001b[1;1HFrame 0"]
      [0.5, "o", "\\u001b[H\\u001b[1;1HFrame 1\\u001b[2;1HRow 2"]
      [1.0, "o", "\\u001b[H\\u001b[1;1HFrame 2 Final"]
      CAST

    it "loads cast files and reconstructs visual frames" do
      vcr = Opal::VCR.new
      vcr.load(sample_cast)

      vcr.total_frames.should eq(3)
      vcr.duration.should eq(1.0)

      # Frame 0
      f0 = vcr.goto_frame(0)
      f0.index.should eq(0)
      f0.time.should eq(0.0)
      vcr.current_buffer.get(0, 0).char.should eq('F')
      vcr.current_buffer.get(6, 0).char.should eq('0')

      # Next frame -> Frame 1
      f1 = vcr.next_frame
      f1.index.should eq(1)
      f1.time.should eq(0.5)
      vcr.current_buffer.get(6, 0).char.should eq('1')
      vcr.current_buffer.get(0, 1).char.should eq('R')

      # Next frame -> Frame 2
      f2 = vcr.next_frame
      f2.index.should eq(2)
      f2.time.should eq(1.0)
      vcr.current_buffer.get(6, 0).char.should eq('2')

      # Step backward -> Frame 1
      prev = vcr.prev_frame
      prev.index.should eq(1)
      vcr.current_buffer.get(6, 0).char.should eq('1')

      # Rewind to start
      start_frame = vcr.rewind
      start_frame.index.should eq(0)
      vcr.current_buffer.get(6, 0).char.should eq('0')

      # Seek by timestamp
      seek_frame = vcr.seek(0.6)
      seek_frame.index.should eq(1)
    end

    it "respects overlays when compositing into an existing buffer" do
      vcr = Opal::VCR.new
      vcr.load(sample_cast)
      vcr.goto_frame(0)

      target = Opal::UI::Buffer.new(30, 6)
      # Fill background with background dots
      (0...6).each do |y|
        (0...30).each do |x|
          target.set(x, y, Opal::UI::Cell.new('.'))
        end
      end

      # Render with respect_overlays: true
      vcr.render_frame(target, x: 2, y: 1, respect_overlays: true)

      # At (2, 1) should be 'F' from "Frame 0"
      target.get(2, 1).char.should eq('F')
      # At (0, 0) should still be '.'
      target.get(0, 0).char.should eq('.')
      # Unwritten cells in the 20x4 area should preserve '.' because respect_overlays is true
      target.get(25, 1).char.should eq('.')
    end
  end
end
