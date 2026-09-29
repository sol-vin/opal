require "./prompt/ask"
require "./prompt/confirm"
require "./prompt/select"
require "./prompt/multi_select"
require "./prompt/spinner"
require "./prompt/progress"

module Opal
  module Prompt
    def self.ask(question : String, default : String? = nil, required : Bool = false, driver : Terminal::Driver? = nil) : String
      Ask.run(question, default, required, driver)
    end

    def self.confirm(question : String, default : Bool = true, driver : Terminal::Driver? = nil) : Bool
      Confirm.run(question, default, driver)
    end

    def self.select(question : String, options : Array(String), default_index : Int32 = 0, driver : Terminal::Driver? = nil) : String
      Select.run(question, options, default_index, driver)
    end

    def self.multi_select(question : String, options : Array(String), default_indices : Array(Int32) = [] of Int32, driver : Terminal::Driver? = nil) : Array(String)
      MultiSelect.run(question, options, default_indices, driver)
    end

    def self.spinner(text : String, driver : Terminal::Driver? = nil, &block : Spinner -> T) : T forall T
      Spinner.start(text, driver, &block)
    end

    def self.progress(total : Int32, bar_width : Int32 = 30, color : Color | Symbol | String = :cyan, title : String? = nil, driver : Terminal::Driver? = nil, &block : ProgressBar -> Nil) : Nil
      ProgressBar.run(total, bar_width, color, title, driver, &block)
    end
  end

  # Top-level Opal shortcuts
  def self.ask(question : String, default : String? = nil, required : Bool = false) : String
    Prompt.ask(question, default, required)
  end

  def self.confirm(question : String, default : Bool = true) : Bool
    Prompt.confirm(question, default)
  end

  def self.select(question : String, options : Array(String), default_index : Int32 = 0) : String
    Prompt.select(question, options, default_index)
  end

  def self.multi_select(question : String, options : Array(String), default_indices : Array(Int32) = [] of Int32) : Array(String)
    Prompt.multi_select(question, options, default_indices)
  end

  def self.spinner(text : String, &block : Prompt::Spinner -> T) : T forall T
    Prompt.spinner(text, &block)
  end

  def self.progress(total : Int32, bar_width : Int32 = 30, color : Color | Symbol | String = :cyan, title : String? = nil, &block : Prompt::ProgressBar -> Nil) : Nil
    Prompt.progress(total, bar_width, color, title, &block)
  end
end
