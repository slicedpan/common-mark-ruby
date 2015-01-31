module CommonMark
  module NodeTypes
    class List < Node
      def continue
        0        
      end

      def finalize(parser)
        item = self.first_child;
        while (item) do
            # check for non-final list item ending with blank line:
          if (ends_with_blank_line(item) && item.next)
            self._list_data.tight = false;
            break;
          end
          # recurse into children of list item, to see if there are
          # spaces between any of them:
          sub_item = item.first_child;
          while (sub_item) do
            if ends_with_blank_line(sub_item) && (item.next || sub_item.next)
              self._list_data.tight = false;
              break
            end
            subitem = subitem.next;
          end
          item = item.next;
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
          if block.last_line_blank
            return true
          end
          t = block.type
          if t == 'List' || t == 'Item'
            block = block.last_child
          else
            break
          end
        end
        false
      end

    end
  end
end