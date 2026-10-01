require "../spec_helper"

describe Opal::UI::BinaryMetrics do
  it "initializes and renders section and function charts into buffer" do
    metrics = Opal::UI::BinaryMetrics.new(
      target_name: "game.dll",
      total_size: 5_000_000_u64,
      code_size: 3_000_000_u64,
      title: "TEST BINARY METRICS"
    )

    metrics.add_section(".text", 3_000_000_u64, 60.0, is_code: true)
    metrics.add_section(".rdata", 1_000_000_u64, 20.0)
    metrics.add_section(".data", 1_000_000_u64, 20.0, is_data: true)

    metrics.add_function("TestClass::run", 50_000_u64, complexity: 12)
    metrics.add_function("init_all", 20_000_u64, complexity: 5)

    metrics.add_hardening("ASLR", true)
    metrics.add_hardening("DEP", true)

    buffer = Opal::UI::Buffer.new(80, 24)
    metrics.render(buffer, 0, 0, 80, 24)
    rendered = buffer.render_to_string

    rendered.should contain("TEST BINARY METRICS")
    rendered.should contain("game.dll")
    rendered.should contain(".text")
    rendered.should contain("TestClass::run")
    rendered.should contain("ASLR")
    rendered.should contain("CODE:")
  end
end