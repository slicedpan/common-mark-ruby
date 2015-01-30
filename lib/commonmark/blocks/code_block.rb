module CommonMark
  module Blocks
    class CodeBlock < Block

      CLOSING_CODE_FENCE_REGEX = /^(?:`{3,}|~{3,})(?= *$)/

      def continue(parser, container, non_next_space)
        line = parser.current_line
        indent = non_next_space - parser.offset;
        if (container._fenced?) #fenced
          match = (indent <= 3 && line[non_next_space] == container._fence_char && line.slice(non_next_space, line.length - 1).match(CLOSING_CODE_FENCE_REGEX))
          if (match && match[0].length >= container._fence_length)
            #closing fence - we're at end of line, so we can return
            parser.finalize(container, parser.line_number);
            return 2
          else
            # skip optional spaces of fence offset
            var i = container._fence_offset;
            while i > 0 && line[parser.offset] == ' ' do
              parser.offset++;
              i -= 1
            end
          end
        else #indented
          if indent >= Parser::CODE_INDENT
            parser.offset += Parser::CODE_INDENT
          elsif (non_next_space === line.length) #blank
            parser.offset = non_next_space
          else
            return 1
          end
        end
        0
      end

      def finalize(parser, block)
        if block._fenced?)  #fenced
          #first line becomes info string
          content = block._string_content
          new_line_pos = content.index("\n")
          first_line = content.slice(0, new_line_pos)
          rest = content.slice(new_line_pos, content.length)
          block.info = unescapeString(firstLine.trim())
          block._literal = rest;
        } else { // indented
          block._literal = block._string_content.replace(/(\n *)+$/, '\n');
        }
        block._string_content = null; // allow GC
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