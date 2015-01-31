module CommonMark
  class Parser

    LINE_ENDING_REGEX = /\r\n|\n|\r/
    NON_SPACE_REGEX = /[^ \t\n]/
    MAYBE_SPECIAL_REGEX = /^[#`~*+_=<>0-9-]/
    ATX_HEADER_MARKER_REGEX = /^#{1,6}(?: +|$)/
    CODE_FENCE_REGEX = /^`{3,}(?!.*`)|^~{3,}(?!.*~)/
    SETEXT_HEADER_LINE_REGEX = /^(?:=+|-+) *$/
    HRULE_REGEX = /^(?:(?:\* *){3,}|(?:_ *){3,}|(?:- *){3,}) *$/;

    BLOCKTAGNAME = '(?:article|header|aside|hgroup|iframe|blockquote|hr|body|li|map|button|object|canvas|ol|caption|output|col|p|colgroup|pre|dd|progress|div|section|dl|table|td|dt|tbody|embed|textarea|fieldset|tfoot|figcaption|th|figure|thead|footer|footer|tr|form|ul|h1|h2|h3|h4|h5|h6|video|script|style)'
    HTMLBLOCKOPEN = "<(?:" + BLOCKTAGNAME + "[\\s/>]" + "|" + "/" + BLOCKTAGNAME + "[\\s>]" + "|" + "[?!])"
    HTML_BLOCK_OPEN_REGEX = Regexp.new('^' + HTMLBLOCKOPEN, 'i')

    attr_reader :current_line
    attr_accessor :offset

    def initialize(options = {})
      @doc = Node.create_document
      @tip = @doc
      @oldtip = @doc
      @current_line = ""
      @line_number = 0
      @offset = 0,
      @allClosed = true,
      @lastMatchedContainer = @doc,
      @refmap = {},
      @lastLineLength = 0,
      @inlineParser =InlineParser.new
      @options = OpenStruct.new(options)
        # breakOutOfLists: breakOutOfLists,
        # addLine: addLine,
        # addChild: addChild,
        # incorporateLine: incorporateLine,
        # finalize: finalize,
        # processInlines: processInlines,
        # closeUnmatchedBlocks: closeUnmatchedBlocks,

    end

    def match_at(regex, string, offset)
      res = string.slice(offset, string.length - 1).match(regex)
      if res.nil?
        -1
      else
        res.offset(0)[0] + offset
      end
    end

    # Add block of type tag as a child of the tip.  If the tip can't
    # accept children, close and finalize it and try its parent,
    # and so on til we find a block that can accept children.
    def add_child(tag, offset)

      while (!tip.canContain(tag)) do
        finalize(this.tip, this.lineNumber - 1)
      end     

      column_number = offset + 1 # offset 0 = column 1
      new_block = NodeTypes.list[tag].new([[this.lineNumber, column_number], [0, 0]])
      new_block.string_content = ''
      this.tip.append_child(new_block)
      this.tip = new_block
      new_block
    end

    def incorporate_line(line)
      all_matched = true;
      next_non_space = nil
      match = nil
      data = nil
      blank = nil
      indent = nil
      t = nil

      container = @doc
      @oldtip = @tip;
      @offset = 0;
      @lineNumber += 1;

      #replace NUL characters for security
      if line.include?('\u0000')
        line = line.gsub(/\0/, '\uFFFD')
      end

      # Convert tabs to spaces:
      line = detab_line(line);
      @current_line = line;

      # For each containing block, try to parse the associated line start.
      # Bail out on failure: container will point to the last matching block.
      # Set all_matched to false if not all containers match.
      last_child = nil
      while (last_child = container._last_child) && last_child._open do
        container = last_child;

        match = match_at(NON_SPACE_REGEX, line, @offset);
        if (match == -1)
          next_non_space = line.length;
       else
          next_non_space = match;
        end

        case @blocks[container.type].continue(@container, next_non_space)
        when 0: # we've matched, keep going
            break;
        when 1: # we've failed to match a block
            all_matched = false;
            break;
        when 2: # we've hit end of line for fenced code close and can return
            @last_line_length = line.length
            return
        else:
            raise CommonMark::ParseException.new('continue returned illegal value, must be 0, 1, or 2')
        end

        if (!all_matched)
            container = container._parent #back up to last matching block
            break;
        end

      end #while

    blank = next_non_space == line.length

    @all_closed = (container == @oldtip)
    @last_matched_container = container

    # Check to see if we've hit 2nd blank line; if so break out of list:
    if (blank && container._last_line_blank)
        break_out_of_lists(container)
    end

    # Unless last matched container is a code block, try new container starts,
    # adding children to the last matched container:
    while !(container.is_a?(CodeBlock)) || !(container.is_a?(HtmlBlock))    

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
        @offset = next_non_space;
        break;
      end

      if indent >= CODE_INDENT
        if @tip.type != 'Paragraph' && !blank
          # indented code
          @offset += CODE_INDENT;
          close_unmatched_blocks
          container = add_child('CodeBlock', @offset);
        else
          # lazy paragraph continuation
          @offset = next_non_space;
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
        @offset = next_non_space + match[0].length;
        close_unmatched_blocks
        container = add_child('Header', next_non_space);
        container.level = match[0].trim().length; # number of #s
        # remove trailing ###s:
        container._string_content = line.slice(@offset).gsub(/^ *#+ *$/, '').gsub(/ +#+ *$/, '')
        @offset = line.length;
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
        container = add_child('HtmlBlock', @offset);
        # don't adjust @offset; spaces are part of block
        break

      elsif t == 'Paragraph' && container._string_content.index("\n") == container._string_content.length - 1) && (match = line.slice(next_non_space, line.length).match(SETEXT_HEADER_LINE_REGEX))
        # setext header line
        close_unmatched_blocks
        header = NodeTypes::Header.new(container.sourcepos)
        header.level = (match[0][0] == '=') ? 1 : 2
        header._string_content = container._string_content
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
        @offset = next_non_space;
        break
      end

    }

    # What remains at the offset is a text line.  Add the text to the
    # appropriate container.

   # First check for a lazy paragraph continuation:
    if (!@allClosed && !blank &&
        @tip.type === 'Paragraph') {
        # lazy paragraph continuation
        @addLine(line);

    } else { # not a lazy continuation

        # finalize any blocks not matched
        close_unmatched_blocks
        if (blank && container.last_child) {
            container.last_child._lastLineBlank = true;
        }

        t = container.type;

        # Block quote lines are never blank as they start with >
        # and we don't count blanks in fenced code for purposes of tight/loose
        # lists or breaking out of lists.  We also don't set _lastLineBlank
        # on an empty list item, or if we just closed a fenced block.
        var lastLineBlank = blank &&
            !(t === 'BlockQuote' ||
              (t === 'CodeBlock' && container._isFenced) ||
              (t === 'Item' &&
               !container._firstChild &&
               container.sourcepos[0][0] === @lineNumber));

        # propagate lastLineBlank up through parents:
        var cont = container;
        while (cont) {
            cont._lastLineBlank = lastLineBlank;
            cont = cont._parent;
        }

        if (@blocks[t].acceptsLines) {
            @addLine(line);
        } else if (@offset < line.length && !blank) {
            # create paragraph container for line
            container = add_child('Paragraph', @offset);
            @offset = next_non_space;
            @addLine(line);
        }
    }
    @lastLineLength = line.length;
      };
    end

    def parse(input)
      @doc = Node.create_document
      @tip = @doc;
      @refmap = {};
      @lineNumber = 0;
      @lastLineLength = 0;
      @offset = 0;
      @lastMatchedContainer = @doc;
      @current_line = "";
      #if (@options.time) { console.time("preparing input"); }
      lines = input.split(LINE_ENDING_REGEX);
      len = lines.length;
      if (input.last == '\n') {
          # ignore last blank line created by final newline
          len -= 1;
      }
      #if (@options.time) { console.timeEnd("preparing input"); }
      #if (@options.time) { console.time("block parsing"); }
      lines.each{ |line| incorporate_line(line) }
      while (!@tip.nil?) {
          finalize(@tip, len);
      }
      #if (@options.time) { console.timeEnd("block parsing"); }
      #if (@options.time) { console.time("inline parsing"); }
      process_inlines(@doc);
      #@if (@options.time) { console.timeEnd("inline parsing"); }
      return @doc;
    end

  end
end