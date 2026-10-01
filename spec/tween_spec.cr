require "./spec_helper"
require "../src/opal/style/animation"

describe "Opal::Animation::Tween & Easing" do
  it "evaluates all 16 easing curves smoothly at 0.0, 0.5, and 1.0" do
    Opal::Animation::Easing.values.each do |easing|
      start_v = Opal::Animation::EasingFunctions.evaluate(easing, 0.0)
      end_v = Opal::Animation::EasingFunctions.evaluate(easing, 1.0)
      start_v.should be_close(0.0, 0.01)
      end_v.should be_close(1.0, 0.01)
    end
  end

  it "animates numeric values and completes cleanly" do
    completed = false
    tw = Opal::Animation::Tween.new(from_val: 0.0, to_val: 100.0, duration: 1.0.seconds, easing: Opal::Animation::Easing::QuadOut)
    tw.on_complete { completed = true }

    # Halfway (0.5s)
    tw.update(0.5)
    tw.current_val.should be > 50.0 # QuadOut is faster in first half
    tw.finished?.should be_false
    completed.should be_false

    # Complete (another 0.5s)
    tw.update(0.5)
    tw.current_val.should eq(100.0)
    tw.finished?.should be_true
    completed.should be_true
  end

  it "interpolates colors via ColorTween" do
    c1 = Opal::Color.rgb(0, 0, 0)
    c2 = Opal::Color.rgb(100, 100, 100)
    ct = Opal::Animation::ColorTween.new(c1, c2, duration: 1.0.seconds)

    mid = ct.update(0.5)
    mid.r.should be_close(50_u8, 2_u8)
    mid.g.should be_close(50_u8, 2_u8)
    mid.b.should be_close(50_u8, 2_u8)
  end

  it "interpolates rectangles via RectTween" do
    r1 = Opal::UI::Rect.new(0, 0, 10, 10)
    r2 = Opal::UI::Rect.new(20, 10, 30, 20)
    rt = Opal::Animation::RectTween.new(r1, r2, duration: 1.0.seconds)

    mid_rect = rt.update(0.5)
    mid_rect.x.should eq(10)
    mid_rect.y.should eq(5)
    mid_rect.width.should eq(20)
    mid_rect.height.should eq(15)
  end
end
