# frozen_string_literal: true

module EnumMachineContrib
  class DecisionGraph

    attr_accessor :vertexes, :edges

    def initialize(graph)
      @vertexes = Set.new
      @edges    = Set.new

      vertex_by_value = {}
      graph.each do |from_value, to_value_list|
        from_value = array_wrap(from_value)
        vertex_by_value[from_value] ||= Vertex[from_value]
        from_vertex = vertex_by_value[from_value]
        @vertexes << from_vertex

        to_value_list.sort_by(&:to_s).each do |to_value|
          to_value = array_wrap(to_value)
          vertex_by_value[to_value] ||= Vertex[to_value]
          to_vertex = vertex_by_value[to_value]
          @vertexes << to_vertex

          @edges << from_vertex.edge_to(to_vertex)
        end
      end
    end

    def decision_tree
      drop_self_cycled_edges!
      combine_equal_vertexes!

      loop do
        complexity_was = complexity

        decision_tree = DecisionTree.wrap(to_h)
        decision_tree.resolve!
        resolved_decision_tree = decision_tree.resolved

        edges.each do |edge|
          next unless resolved_decision_tree.key?(edge.from.value)

          if resolved_decision_tree[edge.from.value].any? { |to_value_list| to_value_list.include?(edge.to.value) }
            edge.resolved!
          end
        end

        strongly_connected_components = decision_tree.values.filter(&:cycled?)
        strongly_connected_components.each do |strongly_connected_component|
          resolve_strong_component!(strongly_connected_component)
        end

        break if complexity == complexity_was
      end

      decision_tree = DecisionTree[vertexes.index_by(&:value)]
      decision_tree.resolve!
      decision_tree
    end

    def to_h
      vertexes.filter(&:active?).to_h do |vertex|
        [
          vertex.value,
          vertex.outcoming_edges.map { |edge| edge.to.value },
        ]
      end
    end

    private def complexity
      edges.count(&:active?)
    end

    private def drop_self_cycled_edges!
      edges.each do |edge|
        edge.dropped! if edge.from == edge.to
      end
    end

    private def combine_equal_vertexes!
      vertexes.group_by { |vertex| [vertex.incoming_edges.map(&:from), vertex.outcoming_edges.map(&:to)] }.each_value do |combining_vertexes|
        next if combining_vertexes.size < 2

        new_vertex = Vertex.replace!(combining_vertexes)
        new_vertex.combined!

        @vertexes << new_vertex

        @edges.merge(new_vertex.incoming_edges)
        @edges.merge(new_vertex.outcoming_edges)
      end
    end

    def resolve_strong_component!(component_cycled_vertex) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      input_values  = component_cycled_vertex.incoming_edges.flat_map { |edge| edge.from.value }
      output_values = component_cycled_vertex.outcoming_edges.flat_map { |vertex| vertex.to.value }

      active_vertexes = vertexes.filter(&:active?)
      input_vertexes  = active_vertexes.reject { |vertex| (input_values & vertex.value).empty? }
      output_vertexes = active_vertexes.reject { |vertex| (output_values & vertex.value).empty? }

      component_vertexes = active_vertexes.reject { |vertex| (component_cycled_vertex.value & vertex.value).empty? }

      component_vertexes.each do |vertex|
        vertex.incoming_edges.each do |edge|
          if (input_vertexes + component_vertexes).exclude?(edge.from)
            # drop insignificant incoming edges
            edge.dropped!
          end
        end
      end

      single_incoming_vertexes = (component_vertexes + output_vertexes).filter { |vertex| vertex.incoming_edges.size == 1 }

      single_incoming_chains = []
      single_incoming_vertexes.each do |vertex|
        single_incoming_edge = vertex.incoming_edges.first
        single_incoming_edge.resolved!

        current_chain = single_incoming_chains.detect { |chain| chain.first == single_incoming_edge.to || chain.last == single_incoming_edge.from }
        if current_chain
          current_chain.replace(
            if current_chain.first == single_incoming_edge.to
              current_chain.unshift(single_incoming_edge.from)
            else
              current_chain.push(single_incoming_edge.to)
            end,
          )
        else
          single_incoming_chains << [single_incoming_edge.from, single_incoming_edge.to]
        end
      end

      single_incoming_chains.each do |chain|
        chain_preceding_vertexes  = chain[0].incoming_edges.map(&:from) & (input_vertexes + component_vertexes)
        chain_achievable_vertexes = chain[1..-1].flat_map { |vertex| vertex.outcoming_edges.map(&:to) }

        pre_chain_vertexes = chain_preceding_vertexes - chain_achievable_vertexes

        if pre_chain_vertexes.size == 1
          single_incoming_edge = chain[0].incoming_edges.detect { |edge| edge.from == pre_chain_vertexes[0] }
          single_incoming_edge.resolved!

          chain.unshift(single_incoming_edge.from)
        end

        chain.flat_map { |vertex| vertex.outcoming_edges.to_a }.group_by(&:to).each_value do |outcoming_edges|
          next if outcoming_edges.size < 2

          outcoming_edges[0..outcoming_edges.size - 2].each(&:dropped!)
        end
      end

      around_vertexes = input_vertexes + component_vertexes + output_vertexes

      component_vertexes.each do |maybe_bottlneck_vertex|
        rest_vertexes = around_vertexes.excluding(maybe_bottlneck_vertex)

        input_achievable_vertexes = next_achievable_vertexes(input_vertexes[0], rest_vertexes, visited: Set.new([maybe_bottlneck_vertex]))
        next if input_achievable_vertexes.size == rest_vertexes.size

        maybe_bottlneck_vertex.outcoming_edges.each do |current_edge|
          if input_achievable_vertexes.include?(current_edge.to) && maybe_bottlneck_vertex.incoming_edges.map(&:from).exclude?((current_edge.to))
            current_edge.to.incoming_edges.each do |edge|
              unless edge.from == maybe_bottlneck_vertex
                edge.dropped!
              end
            end
          end
        end

        rest_vertexes -= input_achievable_vertexes

        maybe_bottlneck_vertex.incoming_edges.each do |edge|
          if rest_vertexes.include?(edge.from)
            edge.dropped!
          end
        end
      end
    end

    def next_achievable_vertexes(vertex, all, visited: Set.new)
      return [] if visited.include?(vertex)

      achievable_vertexes = [vertex]
      visited << vertex

      vertex.outcoming_edges.each do |edge|
        if all.include?(edge.to)
          achievable_vertexes += next_achievable_vertexes(edge.to, all, visited: visited)
        end
      end

      achievable_vertexes
    end

    private def array_wrap(value)
      if value.nil?
        [nil]
      else
        Array.wrap(value)
      end
    end

  end
end
