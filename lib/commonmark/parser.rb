require 'ostruct'
require 'byebug'

module CommonMark
  class Parser

    LINE_ENDING_REGEX = /\r\n|\n|\r/
    NON_SPACE_REGEX = /[^ \t\n]/
    MAYBE_SPECIAL_REGEX = /^[#`~*+_=<>0-9-]/
    ATX_HEADER_MARKER_REGEX = Regexp.new('^#{1,6}(?: +|$)')
    CODE_FENCE_REGEX = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    SETEXT_HEADER_LINE_REGEX = /^(?:=+|-+) *$/
    HRULE_REGEX = /^(?:(?:\* *){3,}|(?:_ *){3,}|(?:- *){3,}) *$/
    BULLET_LIST_MARKER_REGEX = /^[*+-]( +|$)/
    ORDERED_LIST_MARKER_REGEX = /^(\d+)([.)])( +|$)/

    BLOCKTAGNAME = '(?:article|header|aside|hgroup|iframe|blockquote|hr|body|li|map|button|object|canvas|ol|caption|output|col|p|colgroup|pre|dd|progress|div|section|dl|table|td|dt|tbody|embed|textarea|fieldset|tfoot|figcaption|th|figure|thead|footer|footer|tr|form|ul|h1|h2|h3|h4|h5|h6|video|script|style)'
    HTMLBLOCKOPEN = "<(?:" + BLOCKTAGNAME + "[\\s/>]" + "|" + "/" + BLOCKTAGNAME + "[\\s>]" + "|" + "[?!])"
    HTML_BLOCK_OPEN_REGEX = Regexp.new('^' + HTMLBLOCKOPEN, 'i')

    TAB_SPACES = ['    ', '   ', '  ', ' ']

    attr_reader :current_line
    attr_accessor :offset

    def initialize(options = {})
      @doc = NodeTypes::Document.new([[1, 1], [0, 0]])
      @tip = @doc
      @oldtip = @doc
      @current_line = ""
      @line_number = 0
      @offset = 0,
      @all_closed = true,
      @last_matched_container = @doc,
      @refmap = {},
      @last_line_length = 0,
      @inline_parser = InlineParser.new
      @options = OpenStruct.new(options)
        # break_out_of_lists: break_out_of_lists,
        # addLine: addLine,
        # addChild: addChild,
        # incorporateLine: incorporateLine,
        # finalize: finalize,
        # processInlines: processInlines,
        # closeUnmatchedBlocks: closeUnmatchedBlocks,

    end

    def ends_with_blank_line(block)
      while(block) do
        return true if block.last_line_blank
        t = block.type
        if t == 'List' || t == 'Item'
          block = block.last_child
        else
          break
        end
      end
      false
    end

    # Break out of all containing lists, resetting the tip ofreBulletListMarker the
    # document to the parent of the highest list, and finalizing
    # all the lists.  (This is used to implement the "two blank lines
    # break of of all lists" feature.)

    def break_out_of_lists(block)
      b = block
      last_list = nil
      while (b) do
        last_list = b if b.type == 'List'
        b = b.parent;
      end

      if (last_list)
        while (block != last_list) do
          finalize(block, @line_number);
          block = block.parent;
        end
        finalize(last_list, @line_number);
        @tip = last_list.parent;
      end
    end

    # Add a line to the block at the tip.  We assume the tip
    # can accept lines -- that check should be done before calling this.
    def add_line(line)
      @tip.string_content += line.slice(@offset, line.length) + '\n'
    end

    def match_at(regex, string, offset)
      res = string.slice(offset, string.length - 1).match(regex)
      if res.nil?
        -1
      else
        res.offset(0)[0] + offset
      end
    end

    # Parse a list marker and return data on the marker (type,
    # start, delimiter, bullet character, padding) or nil.
    def parse_list_marker(line, offset, indent)
      rest = line.slice(offset, line.length)
      match = nil
      spaces_after_marker = nil
      data = OpenStruct.new({
        :type => nil,
        :tight => true,  # lists are tight by default
        :bullet_char => nil,
        :start => nil,
        :delimiter => nil,
        :padding => nil,
        :markerOffset => indent 
      })

      return nil if rest.match(HRULE_REGEX)
        
      if match = rest.match(BULLET_LIST_MARKER_REGEX)
        spaces_after_marker = match[1].length
        data.type = 'Bullet'
        data.bullet_char = match[0][0]

      elsif match = rest.match(ORDERED_LIST_MARKER_REGEX)
        spaces_after_marker = match[3].length
        data.type = 'Ordered'
        data.start = match[1].to_i
        data.delimiter = match[2]
      else
        return nil
      end

      blank_item = (match[0].length == rest.length)

      if (spaces_after_marker >= 5 || spaces_after_marker < 1 || blank_item)
        data.padding = match[0].length - spaces_after_marker + 1
      else
        data.padding = match[0].length
      end
      data
    end

    def lists_match(list_data, item_data)
      [:type, :delimiter, :bullet_char].all? { |el| list_data[el] == item_data[el] }
    end

    def close_unmatched_blocks
      if !@all_closed
        while @oldtip != @last_matched_container do
          parent = @oldtip.parent
          finalize(@oldtip, @line_number - 1)
          @oldtop = parent
        end
        @all_closed = true
      end
    end

    # Add block of type tag as a child of the tip.  If the tip can't
    # accept children, close and finalize it and try its parent,
    # and so on til we find a block that can accept children.
    def add_child(tag, offset)

      while (!@tip.can_contain(tag)) do
        finalize(@tip, @lineNumber - 1)
      end     

      column_number = offset + 1 # offset 0 = column 1
      new_block = NodeTypes.list[tag].new([[@line_number, column_number], [0, 0]])
      new_block.string_content = ''
      @tip.append_child(new_block)
      @tip = new_block
      new_block
    end

    def incorporate_line(line)
      all_matched = true
      next_non_space = nil
      match = nil
      data = nil
      blank = nil
      indent = nil
      t = nil

      container = @doc
      @oldtip = @tip
      @offset = 0
      @line_number += 1

      byebug

      #replace NUL characters for security
      if line.include?('\u0000')
        line = line.gsub(/\0/, '\uFFFD')
      end

      # Convert tabs to spaces:
      line = Common.detab_line(line)
      @current_line = line

      # For each containing block, try to parse the associated line start.
      # Bail out on failure: container will point to the last matching block.
      # Set all_matched to false if not all containers match.
      last_child = nil
      while (last_child = container.last_child) && last_child._open do
        container = last_child

        match = match_at(NON_SPACE_REGEX, line, @offset)
        if match == -1
          next_non_space = line.length
        else
          next_non_space = match
        end

        case @blocks[container.type].continue(@container, next_non_space)
        when 0 # we've matched, keep going
            break
        when 1 # we've failed to match a block
            all_matched = false
            break
        when 2 # we've hit end of line for fenced code close and can return
            @last_line_length = line.length
            return
        else
            raise CommonMark::ParseException.new('continue returned illegal value, must be 0, 1, or 2')
        end

        if (!all_matched)
            container = container.parent #back up to last matching block
            break
        end

      end #while

      blank = next_non_space == line.length

      @all_closed = (container == @oldtip)
      @last_matched_container = container

      # Check to see if we've hit 2nd blank line; if so break out of list:
      if (blank && container.last_line_blank)
          break_out_of_lists(container)
      end

      # Unless last matched container is a code block, try new container starts,
      # adding children to the last matched container:
      while !((container.type == 'CodeBlock') || !(container.type == 'HtmlBlock'))    

        match = match_at(NON_SPACE_REGEX, line, @offset)
        if (match == -1)
          next_non_space = line.length
          blank = true
          break
        else
          next_non_space = match
          blank = false
        end
        indent = next_non_space - @offset

        # this is a little performance optimization:
        if indent < CODE_INDENT && !(line.slice(next_non_space, line.length) =~ MAYBE_SPECIAL_REGEX)
          @offset = next_non_space
          break
        end

        if indent >= CODE_INDENT
          if @tip.type != 'Paragraph' && !blank
            # indented code
            @offset += CODE_INDENT
            close_unmatched_blocks
            container = add_child('CodeBlock', @offset)
          else
            # lazy paragraph continuation
            @offset = next_non_space
          end
          break
        elsif line[next_non_space] == '>'
          # blockquote
          @offset = next_non_space + 1
          # optional following space
          @offset += 1 if line[@offset] == ' '            
          close_unmatched_blocks
          container = add_child('BlockQuote', next_non_space)

        elsif match = (line.slice(next_non_space, line.length).match(ATX_HEADER_MARKER_REGEX))
          # ATX header
          @offset = next_non_space + match[0].length
          close_unmatched_blocks
          container = add_child('Header', next_non_space)
          container.level = match[0].trim().length; # number of #s
          # remove trailing ###s:
          container.string_content = line.slice(@offset).gsub(/^ *#+ *$/, '').gsub(/ +#+ *$/, '')
          @offset = line.length
          break

        elsif match = (line.slice(next_non_space, line.length).match(CODE_FENCE_REGEX))
          # fenced code block
          fence_length = match[0].length
          close_unmatched_blocks
          container = add_child('CodeBlock', next_non_space)
          container._is_fenced = true
          container._fence_length = fence_length
          container._fence_char = match[0][0]
          container._fence_offset = indent
          @offset = next_non_space + fence_length

        elsif match_at(HTML_BLOCK_OPEN_REGEX, line, next_non_space) != -1
          # html block
          close_unmatched_blocks
          container = add_child('HtmlBlock', @offset)
          # don't adjust @offset; spaces are part of block
          break

        elsif t == 'Paragraph' && (container.string_content.index("\n") == container.string_content.length - 1) && (match = line.slice(next_non_space, line.length).match(SETEXT_HEADER_LINE_REGEX))
          # setext header line
          close_unmatched_blocks
          header = NodeTypes::Header.new(container.sourcepos)
          header.level = (match[0][0] == '=') ? 1 : 2
          header.string_content = container.string_content
          container.insert_after(header)
          container.unlink
          container = header
          @tip = header
          @offset = line.length
          break

        elsif match_at(HRULE_REGEX, line, next_non_space) != -1
          # hrule
          close_unmatched_blocks
          container = add_child('HorizontalRule', next_non_space)
          @offset = line.length
          break

        elsif (data = parse_list_marker(line, next_non_space, indent))
          # list item
          close_unmatched_blocks
          @offset = next_non_space + data.padding

          # add the list if needed
          if (t != 'List' ||
            !(lists_match(container._list_data, data)))
            container = add_child('List', next_non_space)
            container._listData = data
          end

          # add the list item
          container = add_child('Item', next_non_space)
          container._listData = data

        else
          @offset = next_non_space
          break
        end

      end #while not Code/HTML Block

      # What remains at the offset is a text line.  Add the text to the
      # appropriate container.

      # First check for a lazy paragraph continuation:
      if !@all_closed && !blank && @tip.type == 'Paragraph'
        # lazy paragraph continuation
        add_line(line)

      else # not a lazy continuation

        # finalize any blocks not matched
        close_unmatched_blocks
        if blank && !container.last_child.nil?
          container.last_child.last_line_blank = true
        end

        t = container.type

        # Block quote lines are never blank as they start with >
        # and we don't count blanks in fenced code for purposes of tight/loose
        # lists or breaking out of lists.  We also don't set _lastLineBlank
        # on an empty list item, or if we just closed a fenced block.
        fenced_code_block = (t == 'CodeBlock' && container.fenced?)
        empty_item = (t == 'Item' && container.first_child.nil?)

        last_line_blank = blank && !(t == 'BlockQuote' || fenced_code_block || (empty_item && container.sourcepos[0][0] == @line_number))

        # propagate lastLineBlank up through parents:
        cont = container
        while !cont.nil? do
          cont.last_line_blank = last_line_blank
          cont = cont.parent
        end

        if container.accepts_lines
          add_line(line)
        elsif @offset < line.length && !blank
          # create paragraph container for line
          container = add_child('Paragraph', @offset)
          @offset = next_non_space
          add_line(line)
        end
      end
      @last_line_length = line.length      
    end

    def finalize(block, line_number)
      above = block.parent || @top
      block.open = false
      block.sourcepos[1] = [line_number, @last_line_length]

      block.finalize(self);
      @tip = above;

    end

    def process_inlines(block)      
      walker = block.create_walker
      @inline_parser.refmap = @refmap
      while event = walker.next do
        node = event.node
        t = node.type
        if !event.entering && (t == 'Paragraph' || t == 'Header')
          @inline_parser.parse(node)
        end
      end
    end

    def parse(input)
      @doc = NodeTypes::Document.new([[1, 1], [0, 0]])
      @tip = @doc
      @refmap = {}
      @line_number = 0
      @last_line_length = 0
      @offset = 0
      @last_matched_container = @doc
      @current_line = ""
      #if (@options.time) { console.time("preparing input"); }
      lines = input.split(LINE_ENDING_REGEX)
      len = lines.length
      if (input[-1] == '\n')
        # ignore last blank line created by final newline
        len -= 1
      end
      #if (@options.time) { console.timeEnd("preparing input"); }
      #if (@options.time) { console.time("block parsing"); }
      i = 0
      while line = lines[i] do
        break if i == len
        incorporate_line(line)
        i += 1
      end
      
      while (!@tip.nil?) do
        finalize(@tip, len)
      end
      #if (@options.time) { console.timeEnd("block parsing"); }
      #if (@options.time) { console.time("inline parsing"); }
      #process_inlines(@doc)
      #@if (@options.time) { console.timeEnd("inline parsing"); }
      return @doc
    end

  end
end