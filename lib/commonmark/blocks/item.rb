module CommonMark
  module Blocks
    class Item
      def continue(parser, container, non_next_space)
        if (nextNonspace === parser.currentLine.length) #blank
          parser.offset = non_next_space;
        elsif non_next_space - parser.offset >= container._list_data.marker_offset + container._list_data.padding
          parser.offset += container._list_data.marker_offset + container._list_data.padding;
        else
          return 1
        end
        return 0      
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