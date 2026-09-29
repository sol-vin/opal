require "./spec_helper"

describe "Opal Theme Engine" do
  it "returns the default theme (catppuccin_mocha)" do
    theme = Opal::Theme.current
    theme.name.should eq("catppuccin_mocha")
    theme.primary.type.should eq(Opal::Color::Type::RGB)
  end

  it "resolves pre-registered themes by symbol or string" do
    dracula = Opal::Theme.get(:dracula)
    dracula.name.should eq("dracula")

    nord = Opal::Theme.get("nord")
    nord.name.should eq("nord")

    tokyo = Opal::Theme.get(:tokyo_night)
    tokyo.name.should eq("tokyo_night")
  end

  it "allows setting and switching active theme" do
    Opal.theme = :nord
    Opal.theme.name.should eq("nord")

    # Restore default
    Opal.theme = :catppuccin_mocha
    Opal.theme.name.should eq("catppuccin_mocha")
  end

  it "provides semantic color tokens" do
    theme = Opal::Theme.get(:dracula)
    theme.primary.should_not eq(Opal::Color.none)
    theme.background.should_not eq(Opal::Color.none)
    theme.success.should_not eq(Opal::Color.none)
    theme.danger.should_not eq(Opal::Color.none)
  end
end
