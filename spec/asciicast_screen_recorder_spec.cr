require "./spec_helper"
require "../src/opal/asciicast/screen_recorder"

describe Opal::Asciicast::ScreenRecorder do
  it "records direct buffer snapshots into an asciicast session" do
    temp_cast = File.tempfile("recorder_test", ".cast")
    cast_path = temp_cast.path
    temp_cast.close

    recorder = Opal::Asciicast::ScreenRecorder.new(
      output_path: cast_path,
      width: 40,
      height: 10,
      title: "Direct Buffer Test"
    )

    recorder.start
    recorder.recording?.should be_true

    buf = Opal::UI::Buffer.new(40, 10)
    buf.put_string(0, 0, "Frame 1 Hello")
    recorder.capture_frame(buf, advance: 0.1).should be_true

    buf.put_string(0, 1, "Frame 2 World")
    recorder.capture_frame(buf, advance: 0.2).should be_true

    # Unchanged buffer should be ignored if advance is 0
    recorder.capture_frame(buf, advance: 0.0).should be_false

    recorder.stop
    recorder.recording?.should be_false
    recorder.save

    File.exists?(cast_path).should be_true
    content = File.read(cast_path)
    content.lines.size.should be >= 3 # Header + at least 2 frames
    content.should contain("Frame 1 Hello")
    content.should contain("Frame 2 World")
    content.should contain("Direct Buffer Test")

    File.delete(cast_path) if File.exists?(cast_path)
  end

  it "supports wait_frames, skip_frames, and hold" do
    temp_cast = File.tempfile("recorder_pacing", ".cast")
    cast_path = temp_cast.path
    temp_cast.close

    recorder = Opal::Asciicast::ScreenRecorder.new(cast_path, width: 20, height: 5)
    recorder.start

    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(0, 0, "Pacing Test")
    recorder.capture_frame(buf, advance: 0.1)

    t0 = recorder.current_time
    recorder.wait_frames(3, delay_per_frame: 0.1)
    (recorder.current_time - t0).should be_close(0.3, 0.01)

    recorder.skip_frames(2)
    # The next 2 captures should be skipped
    buf.put_string(0, 1, "Skip 1")
    recorder.capture_frame(buf, advance: 0.1).should be_false
    buf.put_string(0, 1, "Skip 2")
    recorder.capture_frame(buf, advance: 0.1).should be_false
    # Third capture should succeed
    buf.put_string(0, 1, "Recorded")
    recorder.capture_frame(buf, advance: 0.1).should be_true

    t_before_hold = recorder.current_time
    recorder.hold(0.5)
    (recorder.current_time - t_before_hold).should be_close(0.5, 0.01)

    recorder.stop
    File.delete(cast_path) if File.exists?(cast_path)
  end

  it "pauses and resumes recording cleanly" do
    temp_cast = File.tempfile("recorder_pause", ".cast")
    cast_path = temp_cast.path
    temp_cast.close

    recorder = Opal::Asciicast::ScreenRecorder.new(cast_path, width: 20, height: 5)
    recorder.start

    buf1 = Opal::UI::Buffer.new(20, 5)
    buf1.put_string(0, 0, "Before Pause")
    recorder.capture_frame(buf1, advance: 0.1).should be_true

    recorder.pause
    recorder.paused?.should be_true
    buf_paused = Opal::UI::Buffer.new(20, 5)
    buf_paused.put_string(0, 0, "During Pause")
    recorder.capture_frame(buf_paused, advance: 0.1).should be_false

    recorder.resume
    recorder.paused?.should be_false
    buf2 = Opal::UI::Buffer.new(20, 5)
    buf2.put_string(0, 0, "After Resume")
    recorder.capture_frame(buf2, advance: 0.1).should be_true

    recorder.stop
    recorder.save

    content = File.read(cast_path)
    content.should contain("Before Pause")
    content.should_not contain("During Pause")
    content.should contain("After Resume")

    File.delete(cast_path) if File.exists?(cast_path)
  end
end
