module Opal
  module UI
    # DOM Query Engine inspired by Python Textual's query() and query_one().
    # Allows locating widgets and elements within a tree using CSS-like selectors
    # (#id, .class, WidgetType) or Crystal type classes.
    module QueryEngine
      # Recursively finds all elements matching a CSS-like selector string
      def self.query(root : Element, selector : String) : Array(Element)
        results = [] of Element
        trimmed = selector.strip
        return results if trimmed.empty?

        # Compound descendant selector: "Box Button"
        if trimmed.includes?(' ')
          parts = trimmed.split(' ', remove_empty: true)
          current_set = [root] of Element
          parts.each do |part|
            next_set = [] of Element
            current_set.each do |parent|
              next_set.concat(query_single(parent, part))
            end
            current_set = next_set
          end
          return current_set
        end

        query_single(root, trimmed)
      end

      # Recursively finds all elements matching a specific Crystal type class
      def self.query_type(root : Element, klass : T.class) : Array(T) forall T
        results = [] of T
        collect_by_type(root, results)
        results
      end

      private def self.collect_by_type(element : Element, results : Array(T)) : Nil forall T
        if element.is_a?(T)
          results << element
        end
        element.children.each do |child|
          collect_by_type(child, results)
        end
      end

      private def self.query_single(root : Element, token : String) : Array(Element)
        results = [] of Element
        collect_by_token(root, token, results, include_self: true)
        results
      end

      private def self.collect_by_token(element : Element, token : String, results : Array(Element), include_self : Bool = false) : Nil
        if include_self && matches?(element, token)
          results << element
        end

        element.children.each do |child|
          if matches?(child, token)
            results << child
          end
          collect_by_token(child, token, results, include_self: false)
        end
      end

      # Tests if a single element satisfies a selector token
      def self.matches?(element : Element, token : String) : Bool
        return false if token.empty?

        # 1. ID selector: "#submit-btn"
        if token.starts_with?('#')
          req_id = token[1..-1]
          return element.id == req_id
        end

        # 2. Class selector: ".primary"
        if token.starts_with?('.')
          req_class = token[1..-1]
          return element.classes.includes?(req_class)
        end

        # 3. Type + Class compound: "Button.danger"
        if token.includes?('.')
          parts = token.split('.', 2)
          type_name = parts[0]
          class_name = parts[1]
          return matches_type?(element, type_name) && element.classes.includes?(class_name)
        end

        # 4. Type selector: "Button" or "switch"
        matches_type?(element, token)
      end

      private def self.matches_type?(element : Element, type_str : String) : Bool
        el_type = element.class.name.split("::").last.downcase
        target_type = type_str.downcase
        el_type == target_type
      end
    end
  end
end
