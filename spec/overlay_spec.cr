require "./spec_helper"

describe "Opal Overlays and Blitting" do
  it "blits a sub-buffer onto a parent buffer" do
    parent = Opal::UI::Buffer.new(10, 5)
    child = Opal::UI::Buffer.new(4, 2)
    child.put_string(0, 0, "HI!!")
    child.put_string(0, 1, "OPAL")

    parent.blit(child, 2, 1)

    parent.get(2, 1).char.should eq('H')
    parent.get(3, 1).char.should eq('I')
    parent.get(2, 2).char.should eq('O')
    parent.get(3, 2).char.should eq('P')
  end

  it "dims rectangular areas of a buffer" do
    buf = Opal::UI::Buffer.new(5, 5)
    buf.put_char(1, 1, 'X')
    buf.get(1, 1).dim?.should be_false

    buf.dim_rect(1, 1, 2, 2)
    buf.get(1, 1).dim?.should be_true
    buf.get(0, 0).dim?.should be_false
  end

  it "renders a centered Modal dialog" do
    buf = Opal::UI::Buffer.new(40, 12)
    modal = Opal::UI::Modal.new(
      title: "Alert",
      message: "Are you sure?",
      buttons: ["Cancel", "OK"],
      selected_button: 1
    )
    modal.render(buf, 0, 0, 40, 12)

    str = buf.to_s
    str.should contain("Alert")
    str.should contain("Are you sure?")
    str.should contain("[ Cancel ]")
    str.should contain("[ OK ]")
  end

  it "manages toast notifications and cleans expired ones" do
    mgr = Opal::UI::ToastManager.new
    mgr.add("Saved", "File saved cleanly", level: :success, duration_ms: 50_i64)
    mgr.add("Notice", level: :info, duration_ms: 1000_i64)

    mgr.size.should eq(2)
    mgr.any?.should be_true

    # Advance time to expire first toast
    later = Time.instant + 100.milliseconds
    mgr.clean_expired(later)
    mgr.size.should eq(1)
    mgr.toasts.first.title.should eq("Notice")
  end
end
