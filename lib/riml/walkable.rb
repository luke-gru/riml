module Riml
  module Walkable
    include Enumerable

    def each(&block)
      children.each(&block)
    end
    alias walk each

    def previous
      idx = index_by_member
      if idx && parent.members[idx - 1]
        attr = parent.members[idx - 1]
        return send(attr)
      else
        idx = index_by_children
        return unless idx
        parent.children.fetch(idx - 1)
      end
    end

    def child_previous_to(node)
      node.previous
    end

    def insert_before(node, new_node)
      idx = children.find_index(node)
      return unless idx
      children.insert(idx - 1, new_node)
    end

    def next
      idx = index_by_member
      if idx && parent.members[idx + 1]
        attr = parent.members[idx + 1]
        return parent.send(attr)
      else
        idx = index_by_children
        return unless idx
        parent.children.fetch(idx + 1)
      end
    end

    def child_after(node)
      node.next
    end

    def insert_after(node, new_node)
      idx = children.find_index(node)
      return unless idx
      children.insert(idx + 1, new_node)
    end

    def index_by_member
      attrs = parent.members
      attrs.each_with_index do |attr, i|
        if parent.send(attr) == self
          return i
        end
      end
      nil
    end

    def index_by_children
      parent.children.find_index(self)
    end

    def remove
      idx = index_by_member
      if idx
        attr = parent.members[idx]
        parent.send("#{attr}=", nil)
      else
        idx = index_by_children
        parent.children.slice!(idx) if idx
      end
    end

    def replace_with(new_node)
      idx = index_by_member
      if idx
        attr = parent.members[idx]
        new_node.parent = parent
        parent.send("#{attr}=", new_node)
        new_node
      else
        idx = index_by_children
        return unless idx
        new_node.parent = parent
        parent.children.insert(idx, new_node)
        parent.children.slice!(idx + 1)
        new_node
      end
    end

    def deep_find(&block)
      ret = children.find(&block)
      if ret
        return ret
      else
        children.each do |child|
          ret = child.deep_find(&block)
          return ret if ret
        end
      end
    end

    def deep_remove(&block)
      ret = deep_find(&block)
      if ret
        ret.remove
      end
    end
  end
end
