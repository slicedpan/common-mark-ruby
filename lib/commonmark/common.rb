module CommonMark
  module Common

    BACKSLASH_OR_AMPERSAND_REGEX = /[\\&]/
    ESCAPABLE = '[!"#$%&\'()*+,./:;<=>?@[\\\\\\]^_`{|}~-]'
    ENTITY = "&(?:#x[a-f0-9]{1,8}|#[0-9]{1,8}|[a-z][a-z0-9]{1,31});"
    ENTITY_OR_ESCAPED_CHARACTER_REGEX = RegExp.new('\\\\' + ESCAPABLE + '|' + ENTITY, 'gi');

    def unescape_string(str)
      if (BACKSLASH_OR_AMPERSAND_REGEX.test(s)) {
        return s.replace(ENTITY_OR_ESCAPED_CHARACTER_REGEX, unescapeChar);
      else
        str
      end
    end
  end
end