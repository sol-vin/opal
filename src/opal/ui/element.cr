require "./buffer"
require "./themable"

module Opal
  module UI
    # Base class for all visual components in the declarative UI hierarchy.
    abstract class Element
      include Themable

      property id : String? = nil
      property classes : Set(String) = Set(String).new

      abstract def render(buffer : Buffer, x : Int32, y : Int32, width : Int32, height : Int32) : Nil
      abstract def preferred_size(available_w : Int32, available_h : Int32) : {Int32, Int32}

      # Returns child elements for hierarchical tree traversal and DOM querying
      def children : Array(Element)
        [] of Element
      end

      def add_class(name : String) : self
        @classes << name
        self
      end

      def remove_class(name : String) : self
        @classes.delete(name)
        self
      end

      def has_class?(name : String) : Bool
        @classes.includes?(name)
      end

      # Queries all descendants matching a CSS-like selector string
      def query(selector : String) : Array(Element)
        QueryEngine.query(self, selector)
      end

      # Queries all descendants matching a specific Crystal type class
      def query(klass : T.class) : Array(T) forall T
        QueryEngine.query_type(self, klass)
      end

      # Queries the first descendant matching selector, or nil
      def query_one?(selector : String) : Element?
        query(selector).first?
      end

      # Queries the first descendant matching selector, or raises KeyError
      def query_one(selector : String) : Element
        query_one?(selector) || raise KeyError.new("No element matched selector '#{selector}'")
      end

      # Queries the first descendant matching type class, or nil
      def query_one?(klass : T.class) : T? forall T
        query(klass).first?
      end

      # Queries the first descendant matching type class, or raises KeyError
      def query_one(klass : T.class) : T forall T
        query_one?(klass) || raise KeyError.new("No element matched type #{klass}")
      end
    end
  end
end

require "./input_hookable"
require "./control"
require "./engine"
require "./query"
