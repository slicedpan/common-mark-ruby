module CommonMark
  module NodeTypes
    class Document < Node
      def continue(parser, container, next_non_space)
        0        
      end

      def finalize(parser, block)    
      end

      def can_contain(t)
        t != 'Item'
      end

      def accepts_lines
        false
      end
    end
  end
end