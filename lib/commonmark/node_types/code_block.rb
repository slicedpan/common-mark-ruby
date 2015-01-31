module CommonMark
  module NodeTypes
    class CodeBlock < Node

      CLOSING_CODE_FENCE_REGEX = /^(?:`{3,}|~{3,})(?= *$)/

      attr_accessor :fenced

      def fenced?
        !!@fenced
      end

      def continue(parser, container, next_non_space)
        line = parser.current_line
        indent = next_non_space - parser.offset;
        if (container._fenced?) #fenced
          match = (indent <= 3 && line[next_non_space] == container._fence_char && line.slice(next_non_space, line.length - 1).match(CLOSING_CODE_FENCE_REGEX))
          if (match && match[0].length >= container._fence_length)
            #closing fence - we're at end of line, so we can return
            parser.finalize(container, parser.line_number);
            return 2
          else
            # skip optional spaces of fence offset
            var i = container._fence_offset;
            while i > 0 && line[parser.offset] == ' ' do
              parser.offset += 1
              i -= 1
            end
          end
        else #indented
          if indent >= Parser::CODE_INDENT
            parser.offset += Parser::CODE_INDENT
          elsif (next_non_space === line.length) #blank
            parser.offset = next_non_space
          else
            return 1
          end
        end
        0
      end

      def finalize(parser, block)
        if block.fenced?  #fenced
          #first line becomes info string
          content = block._string_content
          new_line_pos = content.index("\n")
          first_line = content.slice(0, new_line_pos)
          rest = content.slice(new_line_pos, content.length)
          block.info = Common.unescape_string(first_line.strip)
          block._literal = rest;
        else # indented
          block._literal = block._string_content.gsub(/(\n *)+$/, '\n');
        end
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