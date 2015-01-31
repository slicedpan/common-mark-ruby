require 'commonmark/node'

module CommonMark
  module NodeTypes
    def self.add_node_type(type)
      list[type.name.split("::").last] = type
    end

    def self.list
      @lists ||= {}
    end
  end
end

Dir[File.dirname(__FILE__) + "/node_types/*.rb"].each{ |file| require file[0..-4] }