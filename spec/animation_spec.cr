require "./spec_helper"

describe "Opal Animation & Easing" do
  it "calculates linear easing" do
    Opal::Animation.linear(0.0).should eq(0.0)
    Opal::Animation.linear(0.5).should eq(0.5)
    Opal::Animation.linear(1.0).should eq(1.0)
    Opal::Animation.linear(1.5).should eq(1.0)
  end

  it "calculates quadratic easing" do
    Opal::Animation.ease_in_quad(0.5).should eq(0.25)
    Opal::Animation.ease_out_quad(0.5).should eq(0.75)
    Opal::Animation.ease_in_out_quad(0.5).should eq(0.5)
  end

  it "calculates bounce and elastic easing" do
    Opal::Animation.bounce_out(0.0).should be_close(0.0, 0.01)
    Opal::Animation.bounce_out(1.0).should be_close(1.0, 0.01)
    Opal::Animation.elastic_out(0.0).should eq(0.0)
    Opal::Animation.elastic_out(1.0).should eq(1.0)
  end

  it "linearly interpolates between two colors (lerp)" do
    black = Opal::Color.rgb(0, 0, 0)
    white = Opal::Color.rgb(200, 200, 200)

    mid = Opal::Color.lerp(black, white, 0.5)
    mid.r.should eq(100)
    mid.g.should eq(100)
    mid.b.should eq(100)

    start_c = Opal::Color.lerp(black, white, 0.0)
    start_c.r.should eq(0)

    end_c = Opal::Color.lerp(black, white, 1.0)
    end_c.r.should eq(200)
  end

  it "computes current value for Tween" do
    tween = Opal::Animation::Tween.new(
      from: 10.0,
      to: 20.0,
      duration_ms: 100_i64,
      start_time: Time.instant
    )
    tween.current_value.should be >= 10.0
    tween.current_value.should be <= 20.0
  end
end
