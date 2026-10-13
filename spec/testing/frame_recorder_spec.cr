require "../spec_helper"

describe Opal::Testing::FrameRecorder do
  it "records successive buffer snapshots over time" do
    recorder = create_frame_recorder
    recorder.empty?.should be_true

    buf = Opal::UI::Buffer.new(20, 2)

    # Frame 1: Initialization
    buf.put_string(0, 0, "Status: Connecting")
    recorder.record(buf)

    # Frame 2: Progress
    buf.clear
    buf.put_string(0, 0, "Status: 50% Complete")
    recorder.record(buf)

    # Frame 3: Finished
    buf.clear
    buf.put_string(0, 0, "Status: Done!")
    recorder.record(buf)

    recorder.size.should eq(3)
    recorder.empty?.should be_false

    # Assert individual frame progression (Ink style)
    recorder.frames[0].should contain("Status: Connecting")
    recorder.frames[1].should contain("Status: 50% Complete")
    recorder.frames[2].should contain("Status: Done!")
    recorder.last_frame.should contain("Status: Done!")

    # Verify deep buffer snapshots are preserved
    recorder.buffers[0].screenshot(format: :text).should contain("Status: Connecting")
    recorder.buffers[2].screenshot(format: :text).should contain("Status: Done!")
  end

  it "records string-based terminal frames directly" do
    recorder = Opal::Testing::FrameRecorder.new
    recorder.record("Frame Alpha")
    recorder.record("Frame Beta")

    recorder.size.should eq(2)
    recorder.last_frame.should eq("Frame Beta")

    recorder.clear
    recorder.empty?.should be_true
    recorder.last_frame.should eq("")
  end
end
