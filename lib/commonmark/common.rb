module CommonMark
  module Common

    BACKSLASH_OR_AMPERSAND_REGEX = /[\\&]/
    ESCAPABLE = '[!"#$%&\'()*+,.\/:;<=>?@[\\\\\\]^_`{|}~-]'
    ENTITY = "&(?:#x[a-f0-9]{1,8}|#[0-9]{1,8}|[a-z][a-z0-9]{1,31});"
    ENTITY_OR_ESCAPED_CHARACTER_REGEX = /\\[!"#$%&'()*+,.\/:;<=>?@\[\]^_`{|}~-]|&(?:#x[a-f0-9]{1,8}|#[0-9]{1,8}|[a-z][a-z0-9]{1,31});/
    def self.unescape_character(c)
      if c[0] == '\\'
        c[1]
      else
        HTML5Entities.entity_to_char(c)
      end
    end

    def self.unescape_string(str)
      if str =~ BACKSLASH_OR_AMPERSAND_REGEX
        str.gsub(ENTITY_OR_ESCAPED_CHARACTER_REGEX){ |c| unescape_character(c) }
      else
        str
      end
    end
  end
end