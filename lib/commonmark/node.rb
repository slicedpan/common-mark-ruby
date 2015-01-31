module CommonMark
  class Node

    def self.inherited(other)
      NodeTypes.add_node_type(other)
    end

    attr_accessor :first_child, :last_child, :next, :previous, :parent, :source_pos, :literal,
      :title, :info, :level, :list_type, :list_tight, :list_start, :list_delimiter, :string_content, 
      :last_line_blank

    def create_walker
      NodeWalker.new(self)
    end

    def type
      self.class.name
    end

    def initialize(src_pos)
      @source_pos = src_pos
    end

    def container?
      false
    end

    def append_child(child)
      child.unlink
      child.parent = self
      if self.last_child.nil?
        self.last_child = child
        self.first_child = child
      else
        self.last_child.next = child
        child.previous = self.last_child
        self.last_child = child
      end
    end

    def prepend_child(child)
      child.unlink
      child.parent = self
      if self.first_child.nil?
        self.first_child = child
        self.last_child = child
      else
        self.first_child.previous = child
        child.next = self.first_child
        self.first_child = child
      end
    end

    def unlink
      if !self.previous.nil?
        self.previous.next = self.next
      elsif !self.parent.nil?
        self.parent.first_child = self.next
      end

      if !self.next.nil?
        self.next.previous = self.previous
      elsif !self.parent.nil?
        self.parent.last_child = self.previous
      end

      self.parent = nil
      self.next = nil
      self.previous = nil
    end

    def insert_after(sibling)
      sibling.unlink()
      sibling.next = self.next
      if !sibling.next.nil?
        sibling.next.previous = sibling
      end
      sibling.previous = self
      self.next = sibling
      sibling.parent = self.parent
      sibling.parent.last_child = sibling if sibling.next.nil?
    end

    def insert_before(sibling)
      sibling.unlink()
      sibling.previous = self.previous
      if !sibling.previous.nil?
        sibling.previous.next = sibling
      end
      sibling.next = self
      self.previous = sibling
      sibling.parent = self.parent
      sibling.parent.first_child = sibling if sibling.previous.nil?
    end

  end
end