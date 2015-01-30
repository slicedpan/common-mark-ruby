module CommonMark
  module Blocks
    class Header < Block
      def continue(parser, container, non_next_space)
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