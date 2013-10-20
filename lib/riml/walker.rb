module Riml
  class Walker
    MAX_RECURSION_LVL_ACTUAL = 1_000_000

    def self.walk_node(node, method, max_recursion_lvl = -1)
      if max_recursion_lvl == -1
        max_recursion_lvl = MAX_RECURSION_LVL_ACTUAL
      end
      # breadth-first walk
      to_visit = [node]
      lvl = 0
      while to_visit.length > 0
        cur_node = to_visit.shift
        cur_node.children.each do |child|
          to_visit << child
        end if lvl < max_recursion_lvl && cur_node.respond_to?(:children)
        method.call(cur_node)
        lvl += 1
      end
    end
  end
end
