module CommonMark
  module NodeTypes
    class Item < Node
      def continue(parser, container, next_non_space)
        if (next_non_space === parser.currentLine.length) #blank
          parser.offset = next_non_space;
        elsif next_non_space - parser.offset >= container._list_data.marker_offset + container._list_data.padding
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