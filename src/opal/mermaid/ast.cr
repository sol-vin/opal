module Opal
  module Mermaid
    enum Direction
      TopDown
      LeftRight
      BottomUp
      RightLeft
    end

    enum NodeShape
      Rect
      Round
      Diamond
      Database
      Pill
      Circle
    end

    enum EdgeStyle
      Arrow
      Solid
      Thick
      Dotted
    end

    struct Node
      property id : String
      property label : String
      property shape : NodeShape

      def initialize(@id : String, @label : String = "", @shape : NodeShape = NodeShape::Rect)
        @label = @id if @label.empty?
      end
    end

    struct Edge
      property from_id : String
      property to_id : String
      property label : String?
      property style : EdgeStyle

      def initialize(@from_id : String, @to_id : String, @label : String? = nil, @style : EdgeStyle = EdgeStyle::Arrow)
      end
    end

    struct SequenceMessage
      property from_name : String
      property to_name : String
      property message : String
      property? dashed : Bool

      def initialize(@from_name : String, @to_name : String, @message : String, @dashed : Bool = false)
      end
    end

    abstract class Diagram
    end

    class FlowchartDiagram < Diagram
      property direction : Direction
      property nodes : Hash(String, Node) = Hash(String, Node).new
      property edges : Array(Edge) = [] of Edge

      def initialize(@direction : Direction = Direction::TopDown)
      end
    end

    class SequenceDiagramAST < Diagram
      property participants : Array(String) = [] of String
      property messages : Array(SequenceMessage) = [] of SequenceMessage

      def initialize
      end
    end

    class StateDiagramAST < Diagram
      property states : Array(String) = [] of String
      property transitions : Array(Tuple(String, String, String?)) = [] of Tuple(String, String, String?)

      def initialize
      end
    end

    class ClassDiagramAST < Diagram
      property classes : Hash(String, Array(String)) = Hash(String, Array(String)).new
      property relations : Array(Tuple(String, String, String)) = [] of Tuple(String, String, String)

      def initialize
      end
    end
  end
end
