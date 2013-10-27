# topological sorting module from stdlib
# uses Tarjan's algorithm for strongly connected components
require 'tsort'

module Riml
  class ClassDependencyGraph
    include TSort

    attr_reader :definition_graph, :encountered_graph

    # definition_graph:  { "faster_car.riml" => { "s:FasterCar" => "s:Car" }, "car.riml" => { "s:Car" => nil } }
    # encountered_graph: { "faster_car.riml" => ["s:FasterCar", "s:Car"], "car.riml" => ["s:Car"] }
    def initialize(definition_graph = {}, encountered_graph = {})
      @definition_graph = definition_graph
      @encountered_graph = encountered_graph
      @filename_graph = nil
    end

    def class_defined(filename, class_name, superclass_name)
      @definition_graph[filename] ||= {}
      @definition_graph[filename][class_name] = superclass_name
      class_encountered(filename, class_name)
      class_encountered(filename, superclass_name) if superclass_name
    end

    def class_encountered(filename, class_name)
      @encountered_graph[filename] ||= []
      unless @encountered_graph[filename].include?(class_name)
        @encountered_graph[filename] << class_name
      end
    end

    # order in which filenames need to be included based off internal
    # `@definition_graph` and `@encountered_graph`
    # @return Array filenames
    def tsort
      prepare_filename_graph! if @filename_graph.nil?
      super
    end

    alias filename_order tsort

    # Computes `@filename_graph` from `@encountered_graph` and `@definition_graph`.
    # This graph is used by `tsort` to sort the filenames for inclusion.
    def prepare_filename_graph!
      @filename_graph = {}
      @encountered_graph.each do |filename, encountered_classes|
        defined_in_filename = @definition_graph[filename].keys
        dependent_by_superclass = @definition_graph[filename].values.compact - defined_in_filename
        dependent_by_use = encountered_classes - (defined_in_filename + dependent_by_superclass)
        dependents = dependent_by_superclass + dependent_by_use
        dependents.each do |dep|
          dependent_definition_fname = @definition_graph.detect { |fname, hash| hash.has_key?(dep) }.first rescue nil
          if dependent_definition_fname
            @filename_graph[filename] ||= []
            unless @filename_graph[filename].include?(dependent_definition_fname)
              @filename_graph[filename] << dependent_definition_fname
            end
          end
        end
      end
    end

    def tsort_each_node(&block)
      @filename_graph.each_key(&block)
    end

    def tsort_each_child(node, &block)
      if @filename_graph[node]
        @filename_graph[node].each(&block)
      else
        []
      end
    end

  end
end
