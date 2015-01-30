module CommonMark
  module Blocks
    class List < Block
      def continue
        0        
      end

      def finalize(parser, block)
        item = block._first_child;
        while (item) do
            # check for non-final list item ending with blank line:
          if (ends_with_blank_line(item) && item._next)
            block._list_data.tight = false;
            break;
          end
          # recurse into children of list item, to see if there are
          # spaces between any of them:
          sub_item = item._first_child;
          while (sub_item) do
            if ends_with_blank_line(sub_item) && (item._next || sub_item._next)
              block._list_data.tight = false;
              break
            end
            subitem = subitem._next;
          end
          item = item._next;
        end
      end

      def can_contain(t)
        t != 'Item'
      end

      def accepts_lines
        false
      end

      def ends_with_blank_line(block)
        while(block) do
          if block._last_line_blank
            return true
          end
          t = block.type
          if t == 'List' || t == 'Item'
            block = block._last_child
          else
            break
          end
        end
        false
      end

    end
  end
end