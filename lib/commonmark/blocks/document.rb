module CommonMark
  module Blocks
    class Document < Block
      def continue(parser, container, non_next_space)
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