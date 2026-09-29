require "./spec_helper"

describe "Opal Form DSL" do
  it "edits text and moves cursor in TextField" do
    tf = Opal::FormModule::TextField.new("user", "Username:")
    tf.handle_key(Opal::Terminal::Key.new("a"))
    tf.handle_key(Opal::Terminal::Key.new("b"))
    tf.value.should eq("ab")

    tf.handle_key(Opal::Terminal::Key.new("backspace"))
    tf.value.should eq("a")
  end

  it "cycles options in SelectField" do
    sf = Opal::FormModule::SelectField.new("env", "Environment:", ["dev", "staging", "prod"])
    sf.raw_value.should eq("dev")

    sf.handle_key(Opal::Terminal::Key.new("right"))
    sf.raw_value.should eq("staging")

    sf.handle_key(Opal::Terminal::Key.new("left"))
    sf.raw_value.should eq("dev")
  end

  it "toggles checkboxes in MultiSelectField" do
    msf = Opal::FormModule::MultiSelectField.new("addons", "Addons:", ["Redis", "Postgres", "Elastic"])
    msf.raw_value.as(Array(String)).should be_empty

    # Toggle first option
    msf.handle_key(Opal::Terminal::Key.new("space"))
    msf.raw_value.as(Array(String)).should eq(["Redis"])

    # Move right and toggle second
    msf.handle_key(Opal::Terminal::Key.new("right"))
    msf.handle_key(Opal::Terminal::Key.new("space"))
    msf.raw_value.as(Array(String)).should eq(["Redis", "Postgres"])
  end

  it "toggles ConfirmField" do
    cf = Opal::FormModule::ConfirmField.new("agree", "Agree?", default: false)
    cf.raw_value.should eq(false)

    cf.handle_key(Opal::Terminal::Key.new("y"))
    cf.raw_value.should eq(true)

    cf.handle_key(Opal::Terminal::Key.new("n"))
    cf.raw_value.should eq(false)
  end

  it "validates required fields and reports errors" do
    form = Opal::FormModule::Form.new("Login")
    form.text("username", "User:", required: true)
    form.password("password", "Pass:", min_length: 6)

    # Initial empty form is invalid
    form.valid?.should be_false
    form.fields.first.error.should_not be_nil

    # Fill username
    u_field = form.fields[0].as(Opal::FormModule::TextField)
    u_field.value = "admin"

    # Password still too short
    p_field = form.fields[1].as(Opal::FormModule::PasswordField)
    p_field.value = "123"
    form.valid?.should be_false

    # Make password valid
    p_field.value = "secret123"
    form.valid?.should be_true

    values = form.values
    values["username"].should eq("admin")
    values["password"].should eq("secret123")
  end

  it "navigates focus across fields" do
    form = Opal::FormModule::Form.new("Wizard")
    form.text("f1", "Field 1")
    form.text("f2", "Field 2")

    form.active_field_idx.should eq(0)
    form.focus_next
    form.active_field_idx.should eq(1)
    form.focus_next
    form.active_field_idx.should eq(0)

    form.focus_prev
    form.active_field_idx.should eq(1)
  end
end
