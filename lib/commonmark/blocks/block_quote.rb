module CommonMark
  module Blocks
    class BlockQuote < Block
      def continue(parser, container, non_next_space)
        line = parser.current_line;
        if next_non_space - parser.offset <= 3 && line[next_non_space] == '>'
          parser.offset = next_non_space + 1;
          if line[parser.offset] == ' '
            parser.offset++;
          end
        else
          return 1;
        end
        return 0;        
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