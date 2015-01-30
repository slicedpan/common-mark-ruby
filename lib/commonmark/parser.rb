module CommonMark
  class Parser

    LINE_ENDING_REGEX = /\r\n|\n|\r/
    NON_SPACE_REGEX = /[^ \t\n]/

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
      if (line.include?('\u0000')) {
          line = line.gsub(/\0/, '\uFFFD')
      }

    # Convert tabs to spaces:
    line = detab_line(line);
    @current_line = line;

    # For each containing block, try to parse the associated line start.
    # Bail out on failure: container will point to the last matching block.
    # Set all_matched to false if not all containers match.
    last_child = nil
    while ((last_child = container._last_child) && last_child._open) {
        container = last_child;

        match = match_at(NON_SPACE_REGEX, line, @offset);
        if (match == -1) {
            next_non_space = line.length;
        } else {
            next_non_space = match;
        }

        switch (@blocks[container.type].continue(@ container, next_non_space)) {
        case 0: // we've matched, keep going
            break;
        case 1: // we've failed to match a block
            all_matched = false;
            break;
        case 2: // we've hit end of line for fenced code close and can return
            @lastLineLength = line.length;
            return;
        default:
            throw 'continue returned illegal value, must be 0, 1, or 2';
        }
        if (!all_matched) {
            container = container._parent; // back up to last matching block
            break;
        }
    }

    blank = next_non_space === line.length;

    @allClosed = (container === @oldtip);
    @lastMatchedContainer = container;

    // Check to see if we've hit 2nd blank line; if so break out of list:
    if (blank && container._lastLineBlank) {
        @breakOutOfLists(container);
    }

    // Unless last matched container is a code block, try new container starts,
    // adding children to the last matched container:
    while ((t = container.type) && !(t === 'CodeBlock' || t === 'HtmlBlock')) {

        match = matchAt(reNonSpace, line, @offset);
        if (match === -1) {
            next_non_space = line.length;
            blank = true;
            break;
        } else {
            next_non_space = match;
            blank = false;
        }
        indent = next_non_space - @offset;

        // @is a little performance optimization:
        if (indent < CODE_INDENT && !reMaybeSpecial.test(line.slice(next_non_space))) {
            @offset = next_non_space;
            break;
        }

        if (indent >= CODE_INDENT) {
            if (@tip.type !== 'Paragraph' && !blank) {
                // indented code
                @offset += CODE_INDENT;
                @closeUnmatchedBlocks();
                container = @addChild('CodeBlock', @offset);
            } else {
                // lazy paragraph continuation
                @offset = next_non_space;
            }
            break;

        } else if (line.charAt(next_non_space) === '>') {
            // blockquote
            @offset = next_non_space + 1;
            // optional following space
            if (line.charAt(@offset) === ' ') {
                @offset++;
            }
            @closeUnmatchedBlocks();
            container = @addChild('BlockQuote', next_non_space);

        } else if ((match = line.slice(next_non_space).match(reATXHeaderMarker))) {
            // ATX header
            @offset = next_non_space + match[0].length;
            @closeUnmatchedBlocks();
            container = @addChild('Header', next_non_space);
            container.level = match[0].trim().length; // number of #s
            // remove trailing ###s:
            container._string_content =
                line.slice(@offset).replace(/^ *#+ *$/, '').replace(/ +#+ *$/, '');
            @offset = line.length;
            break;

        } else if ((match = line.slice(next_non_space).match(reCodeFence))) {
            // fenced code block
            var fenceLength = match[0].length;
            @closeUnmatchedBlocks();
            container = @addChild('CodeBlock', next_non_space);
            container._isFenced = true;
            container._fenceLength = fenceLength;
            container._fenceChar = match[0][0];
            container._fenceOffset = indent;
            @offset = next_non_space + fenceLength;

        } else if (matchAt(reHtmlBlockOpen, line, next_non_space) !== -1) {
            // html block
            @closeUnmatchedBlocks();
            container = @addChild('HtmlBlock', @offset);
            // don't adjust @offset; spaces are part of block
            break;

        } else if (t === 'Paragraph' &&
                   (container._string_content.indexOf('\n') ===
                      container._string_content.length - 1) &&
                   ((match = line.slice(next_non_space).match(reSetextHeaderLine)))) {
            // setext header line
            @closeUnmatchedBlocks();
            var header = new Node('Header', container.sourcepos);
            header.level = match[0][0] === '=' ? 1 : 2;
            header._string_content = container._string_content;
            container.insertAfter(header);
            container.unlink();
            container = header;
            @tip = header;
            @offset = line.length;
            break;

        } else if (matchAt(reHrule, line, next_non_space) !== -1) {
            // hrule
            @closeUnmatchedBlocks();
            container = @addChild('HorizontalRule', next_non_space);
            @offset = line.length;
            break;

        } else if ((data = parseListMarker(line, next_non_space, indent))) {
            // list item
            @closeUnmatchedBlocks();
            @offset = next_non_space + data.padding;

            // add the list if needed
            if (t !== 'List' ||
                !(listsMatch(container._listData, data))) {
                container = @addChild('List', next_non_space);
                container._listData = data;
            }

            // add the list item
            container = @addChild('Item', next_non_space);
            container._listData = data;

        } else {
            @offset = next_non_space;
            break;

        }

    }

    // What remains at the offset is a text line.  Add the text to the
    // appropriate container.

   // First check for a lazy paragraph continuation:
    if (!@allClosed && !blank &&
        @tip.type === 'Paragraph') {
        // lazy paragraph continuation
        @addLine(line);

    } else { // not a lazy continuation

        // finalize any blocks not matched
        @closeUnmatchedBlocks();
        if (blank && container.last_child) {
            container.last_child._lastLineBlank = true;
        }

        t = container.type;

        // Block quote lines are never blank as they start with >
        // and we don't count blanks in fenced code for purposes of tight/loose
        // lists or breaking out of lists.  We also don't set _lastLineBlank
        // on an empty list item, or if we just closed a fenced block.
        var lastLineBlank = blank &&
            !(t === 'BlockQuote' ||
              (t === 'CodeBlock' && container._isFenced) ||
              (t === 'Item' &&
               !container._firstChild &&
               container.sourcepos[0][0] === @lineNumber));

        // propagate lastLineBlank up through parents:
        var cont = container;
        while (cont) {
            cont._lastLineBlank = lastLineBlank;
            cont = cont._parent;
        }

        if (@blocks[t].acceptsLines) {
            @addLine(line);
        } else if (@offset < line.length && !blank) {
            // create paragraph container for line
            container = @addChild('Paragraph', @offset);
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