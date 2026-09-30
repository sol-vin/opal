require "./spec_helper"
require "../src/opal/asciicast"
require "../tools/cast_writer"

describe Opal::Asciicast::Header do
  it "serializes to and deserializes from Asciinema v2 JSON format" do
    header = Opal::Asciicast::Header.new(
      width: 100,
      height: 30,
      title: "Test Cast",
      timestamp: 1700000000_i64,
      term: "xterm-256color",
      shell: "/bin/zsh",
      idle_time_limit: 2.5
    )

    json_str = header.to_json
    parsed = Opal::Asciicast::Header.from_json(json_str)

    parsed.version.should eq(2)
    parsed.width.should eq(100)
    parsed.height.should eq(30)
    parsed.title.should eq("Test Cast")
    parsed.timestamp.should eq(1700000000_i64)
    parsed.idle_time_limit.should eq(2.5)
    parsed.env.should_not be_nil
    parsed.env.not_nil!["TERM"].should eq("xterm-256color")
    parsed.env.not_nil!["SHELL"].should eq("/bin/zsh")
  end
end

describe Opal::Asciicast::Event do
  it "creates output, input, and marker events" do
    ev_out = Opal::Asciicast::Event.output(0.5, "hello")
    ev_out.output?.should be_true
    ev_out.input?.should be_false
    ev_out.marker?.should be_false
    ev_out.time.should eq(0.5)
    ev_out.data.should eq("hello")

    ev_in = Opal::Asciicast::Event.input(1.2, "\r")
    ev_in.output?.should be_false
    ev_in.input?.should be_true
    ev_in.marker?.should be_false

    ev_mark = Opal::Asciicast::Event.marker(2.0, "section-1")
    ev_mark.output?.should be_false
    ev_mark.input?.should be_false
    ev_mark.marker?.should be_true
  end

  it "serializes to a 3-element JSON array [time, type, data]" do
    ev = Opal::Asciicast::Event.output(1.234, "foo\nbar")
    json = ev.to_json
    json.should eq(%([1.234,"o","foo\\nbar"]))

    parsed = Opal::Asciicast::Event.from_json(json)
    parsed.time.should eq(1.234)
    parsed.type.should eq("o")
    parsed.data.should eq("foo\nbar")
  end
end

describe Opal::Asciicast::Writer do
  it "records outputs, advances time, and generates valid asciicast JSONL" do
    writer = Opal::Asciicast::Writer.new(width: 80, height: 24, title: "Test Recording")
    writer.write("echo 'hello'", advance: 0.1)
    writer.write("\r\n", advance: 0.05)
    writer.pause(0.5)
    writer.write("hello\r\n", advance: 0.1)

    writer.elapsed.should be_close(0.75, 0.001)
    writer.events.size.should eq(3)

    cast_str = writer.to_s
    lines = cast_str.lines.reject(&.empty?)
    lines.size.should be >= 4 # Header + 3 events + hold frame

    header = Opal::Asciicast::Header.from_json(lines.first)
    header.version.should eq(2)
    header.width.should eq(80)
    header.height.should eq(24)
    header.title.should eq("Test Recording")

    ev1 = Opal::Asciicast::Event.from_json(lines[1])
    ev1.time.should be_close(0.1, 0.001)
    ev1.data.should eq("echo 'hello'")
  end

  it "simulates typing with type_text" do
    writer = Opal::Asciicast::Writer.new
    writer.type_text("cat", cps: 10.0, jitter: 0.0)
    writer.events.size.should eq(3)
    writer.events.map(&.data).join.should eq("cat")
    writer.elapsed.should be > 0.2
  end

  it "renders an Opal::UI::Buffer into the cast timeline with draw_buffer" do
    writer = Opal::Asciicast::Writer.new(width: 20, height: 5)
    buf = Opal::UI::Buffer.new(20, 5)
    buf.put_string(0, 0, "Hello Opal", fg: Opal::Color.cyan, bold: true)
    buf.put_string(0, 1, "Testing Cast", fg: Opal::Color.green)

    writer.draw_buffer(buf, advance: 0.1)
    writer.events.size.should eq(1)

    out_data = writer.events.first.data
    out_data.should contain("Hello Opal")
    out_data.should contain("Testing Cast")
    out_data.should contain("\e[1m") # Bold attribute
  end

  it "saves to disk and creates parent directories" do
    test_path = "tmp/spec_casts/nested/test_session.cast"
    File.delete(test_path) if File.exists?(test_path)

    writer = Opal::Asciicast::Writer.new(width: 80, height: 24, title: "Disk Save Test")
    writer.write("Saved to disk!", advance: 0.1)
    writer.save(test_path)

    File.exists?(test_path).should be_true
    content = File.read(test_path)
    content.should contain(%("title":"Disk Save Test"))
    content.should contain("Saved to disk!")

    # Cleanup
    File.delete(test_path) if File.exists?(test_path)
  end
end

describe Opal::Asciicast::Reader do
  it "parses raw cast string into structured Recording" do
    cast_content = <<-CAST
    {"version":2,"width":80,"height":24,"timestamp":1700000000,"title":"Reader Test","env":{"TERM":"xterm-256color","SHELL":"/bin/bash"}}
    [0.1, "o", "prompt> "]
    [0.2, "i", "ls\\r"]
    [0.3, "o", "file1.cr  file2.cr\\r\\n"]
    [0.5, "m", "end-marker"]
    CAST

    recording = Opal::Asciicast::Reader.from_string(cast_content)
    recording.header.width.should eq(80)
    recording.header.height.should eq(24)
    recording.header.title.should eq("Reader Test")

    recording.events.size.should eq(4)
    recording.duration.should eq(0.5)

    recording.outputs.size.should eq(2)
    recording.inputs.size.should eq(1)
    recording.markers.size.should eq(1)

    recording.total_output_text.should eq("prompt> file1.cr  file2.cr\r\n")
  end

  it "parses saved cast file via Opal::Asciicast.read" do
    test_path = "tmp/spec_casts/read_test.cast"
    File.delete(test_path) if File.exists?(test_path)

    Opal::Asciicast.record(test_path, width: 90, height: 25, title: "DSL Record") do |w|
      w.write("Frame 1", advance: 0.2)
      w.write("Frame 2", advance: 0.3)
    end

    recording = Opal::Asciicast.read(test_path)
    recording.header.width.should eq(90)
    recording.header.height.should eq(25)
    recording.header.title.should eq("DSL Record")
    recording.outputs.map(&.data).should contain("Frame 1")

    # Cleanup
    File.delete(test_path) if File.exists?(test_path)
  end
end

describe Opal::Asciicast::Driver do
  it "acts as an Opal::Terminal::Driver and records writes into an asciicast" do
    driver = Opal::Asciicast::Driver.new(width: 80, height: 24, title: "Driver Spec")
    driver.should be_a(Opal::Terminal::Driver)
    driver.size.should eq({80, 24})

    driver.raw_mode do
      driver.write("Line 1\r\n")
      driver.write("Line 2\r\n")
    end

    driver.in_raw_mode?.should be_false
    driver.writer.events.size.should eq(2)
    driver.writer.events.first.data.should eq("Line 1\r\n")
    driver.writer.events.last.data.should eq("Line 2\r\n")
  end

  it "supports synthetic event injection and reading" do
    driver = Opal::Asciicast.create_driver(width: 80, height: 24)
    driver.read_event.should be_nil

    driver.inject_key("enter")
    driver.inject_key("tab", shift: true)
    driver.inject_mouse(10, 5, Opal::Terminal::MouseButton::Left, Opal::Terminal::MouseAction::Press)

    ev1 = driver.read_event.as(Opal::Terminal::KeyEvent)
    ev1.name.should eq("enter")

    ev2 = driver.read_event.as(Opal::Terminal::KeyEvent)
    ev2.name.should eq("tab")
    ev2.shift?.should be_true

    ev3 = driver.read_event.as(Opal::Terminal::MouseEvent)
    ev3.x.should eq(10)
    ev3.y.should eq(5)
    ev3.button.should eq(Opal::Terminal::MouseButton::Left)

    driver.read_event.should be_nil
  end

  it "allows driving and recording an Opal::UI::Table headlessly" do
    driver = Opal::Asciicast.create_driver(width: 50, height: 10, title: "Table Recording")
    table = Opal::UI::Table.new(
      headers: ["Item", "Qty"],
      rows: [["Apples", "10"], ["Bananas", "25"], ["Cherries", "40"]]
    )

    # Render initial frame into driver
    buf = Opal::UI::Buffer.new(50, 10)
    table.render(buf, 0, 0, 50, 10)
    driver.write(buf.to_s)

    # Simulate moving down twice
    table.move_down
    buf2 = Opal::UI::Buffer.new(50, 10)
    table.render(buf2, 0, 0, 50, 10)
    driver.write(buf2.to_s)

    recording = Opal::Asciicast.read(driver.to_s)
    recording.events.size.should be >= 2
    recording.total_output_text.should contain("Apples")
    recording.total_output_text.should contain("Cherries")
  end
end

describe "Backward Compatibility" do
  it "aliases Opal::Tools::CastWriter to Opal::Asciicast::Writer" do
    Opal::Tools::CastWriter.should eq(Opal::Asciicast::Writer)
  end
end
