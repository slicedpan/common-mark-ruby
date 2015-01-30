module CommonMark
  class Node
    def self.create_document
      Node.new('Document', [[1, 1], [0, 0]])
    end
  end
end