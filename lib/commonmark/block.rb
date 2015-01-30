module CommonMark
  class Block
    def self.inherited(other)
      Blocks.add_block_type(other)
    end

    def type
      self.class.name
    end    
  end
end