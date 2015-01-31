module CommonMark
  module NodeTypes
    class HorizontalRule < Node
      def continue(parser, container, next_non_space)
        1        
      end

      def finalize(parser, block)    
      end

      def can_contain(t)
        false
      end

      def accepts_lines
        false
      end
    end
  end
end