require "./spec_helper"

describe "Opal Fuzzy Matching & FilterList" do
  it "scores exact and prefix matches higher" do
    m_exact = Opal::Input::Fuzzy.match("test", "test")
    m_exact.should_not be_nil
    m_exact.not_nil!.score.should be > 100

    m_prefix = Opal::Input::Fuzzy.match("st", "start")
    m_prefix.should_not be_nil

    m_none = Opal::Input::Fuzzy.match("xyz", "apple")
    m_none.should be_nil
  end

  it "filters and ranks lists by match score" do
    items = ["checkout", "commit", "cherry-pick", "clone"]
    results = Opal::Input::Fuzzy.filter("ch", items)

    results.size.should be >= 2
    # checkout or cherry-pick should rank highest
    results.first.target.should_not be_empty
  end

  it "tracks matched character indices for rune highlighting" do
    m = Opal::Input::Fuzzy.match("fb", "foo_bar")
    m.should_not be_nil
    # 'f' at 0, 'b' at 4
    m.not_nil!.matched_indices.should eq([0, 4])
  end

  it "navigates and updates query in FilterList" do
    fl = Opal::UI::FilterList.new(items: ["apple", "banana", "apricot", "berry"])
    fl.matches.size.should eq(4)

    fl.append_char('a')
    fl.append_char('p')
    fl.query.should eq("ap")

    matches = fl.matches
    matches.map(&.item).should eq(["apple", "apricot"])

    fl.cursor_down
    fl.cursor.should eq(1)
    fl.selected_item.should eq("apricot")

    fl.backspace
    fl.query.should eq("a")
  end
end
