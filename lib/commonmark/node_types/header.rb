module CommonMark
  module NodeTypes
    class Header < Node
      def continue(parser, container, next_non_space)
        1
      end

      def finalize(parser)
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