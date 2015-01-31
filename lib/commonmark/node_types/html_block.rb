module CommonMark
  module NodeTypes
    class HTMLBlock < Node
      def continue(parser, container, next_non_space)
        next_non_space == parser.current_line.length ? 1 : 0
      end

      def finalize(parser)
        self.literal = self.string_content.gsub(/(\n *)+$/, '')
        self.string_content = nil
      end

      def can_contain(t)
        false
      end

      def accepts_lines
        true
      end
    end
  end
end