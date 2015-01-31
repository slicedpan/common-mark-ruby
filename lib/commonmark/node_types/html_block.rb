module CommonMark
  module NodeTypes
    class HTMLBlock < Node
      def continue(parser, container, next_non_space)
        next_non_space == parser.current_line.length ? 1 : 0
      end

      def finalize(parser, block)
        block._literal = block._string_content.gsub(/(\n *)+$/, '')
        block._string_content = nil
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