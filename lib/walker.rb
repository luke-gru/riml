module Riml
  class Walker
    def self.walk_node(node, method, walk_children = lambda {|node| true })
      # breadth-first walk
      to_visit = [node]
      while to_visit.length > 0
        cur_node = to_visit.shift
        cur_node.children.each do |child|
          to_visit << child
        end if cur_node.respond_to?(:children) && walk_children.call(cur_node)
        method.call(cur_node)
      end
    end
  end
end
