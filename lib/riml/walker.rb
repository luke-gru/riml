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
        # use pop and unshift instead of shift and push for performance
        # reasons. This is a hotspot, and `shift` was found to be a big issue
        # using ruby-prof on ruby <= 1.9.3 (not an issue on 2.0.0+)
        cur_node = to_visit.pop
        cur_node.children.each do |child|
          to_visit.unshift(child)
        end if lvl < max_recursion_lvl && cur_node.respond_to?(:children)
        method.call(cur_node)
        lvl += 1
      end
    end
  end
end
