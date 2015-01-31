module CommonMark
  module NodeTypes
    class Paragraph < Node    

      def continue(parser, container, next_non_space)
        next_non_space == parser.current_line.length ? 1 : 0
      end

      def finalize(parser, block)
        pos = nil;
        has_reference_definitions = false;

        # try parsing the beginning as link reference definitions:
        while (block._string_content[0] == '[' && (pos = parser.inline_parser.parse_reference(block._string_content, parser.refmap))) do
          block._string_content = block._string_content.slice(pos, block._string_content.length)
          has_reference_definitions = true
        end
        if (has_reference_definitions && is_blank(block._string_content))
          block.unlink()
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