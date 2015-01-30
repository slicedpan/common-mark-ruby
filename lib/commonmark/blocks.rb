module CommonMark
  module Blocks
    def self.add_block_type(type)
      list[type.name] = type
    end

    def self.list
      @lists ||= {}
    end
  end
end