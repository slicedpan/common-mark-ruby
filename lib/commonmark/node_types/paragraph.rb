module CommonMark
  module NodeTypes
    class Paragraph < Node    

      def continue(parser, container, next_non_space)
        next_non_space == parser.current_line.length ? 1 : 0
      end

      def finalize(parser)
        pos = nil
        has_reference_definitions = false

        # try parsing the beginning as link reference definitions:
        while self.string_content[0] == '[' && (pos = parser.inline_parser.parse_reference(self.string_content, parser.refmap)) do
          self.string_content = self.string_content.slice(pos, self.string_content.length)
          has_reference_definitions = true
        end
        if (has_reference_definitions && is_blank(self.string_content))
          self.unlink
        end
      end

      def can_contain(t)
        false
      end

      def accepts_lines
        true
      end

      def is_blank(str)
        !(str =~ Parser::NON_SPACE_REGEX)
      end

    end
  end
end