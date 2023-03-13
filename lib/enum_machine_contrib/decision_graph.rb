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

          @edges << from_vertex.add_edge(to_vertex)
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
          vertex.outcoming_edges.filter_map { |edge| edge.to.value if edge.active? },
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

    def resolve_strong_component!(component_cycled_vertex)
      input_values  = component_cycled_vertex.incoming_edges.filter(&:active?).flat_map { |edge| edge.from.value }
      output_values = component_cycled_vertex.outcoming_edges.filter(&:active?).flat_map { |vertex| vertex.to.value }

      active_vertexes = vertexes.filter(&:active?)
      input_vertexes = active_vertexes.filter { |vertex| (input_values & vertex.value).any? }
      output_vertexes = active_vertexes.filter { |vertex| (output_values & vertex.value).any? }

      component_vertexes = active_vertexes.filter { |vertex| (component_cycled_vertex.value & vertex.value).any? }

      single_incoming_vertexes = (component_vertexes + output_vertexes).filter { |vertex| vertex.incoming_edges.size == 1 }
      single_incoming_vertexes.each do |to_vertex|
        from_vertex = to_vertex.incoming_edges.first.from

        (from_vertex.incoming_edges + from_vertex.outcoming_edges).group_by { |edge| [edge.from.value.to_s, edge.to.value.to_s].sort }.values.filter { |current_edges| current_edges.size > 1 }.each do |current_edges|
          current_edges.each do |edge|
            # S1 -> S2; S2 -> [S1, S3]
            # drops back reference S2 -> S1
            edge.dropped! if edge.from == from_vertex
          end
        end
      end

      resolved_not_visited_vertexes = []

      current_vertexes = [component_cycled_vertex]
      loop do
        next_vertexes = current_vertexes.flat_map { |vertex| vertex.outcoming_edges.filter_map { |edge| edge.to if edge.active? } }
        resolved_not_visited_vertexes += next_vertexes.reject(&:cycled?)
        current_vertexes = next_vertexes
        break if next_vertexes.empty?
      end

      single_incoming_chains = []
      single_incoming_vertexes.each do |vertex|
        single_incoming_edge = vertex.incoming_edges.first
        # S1 -> [S2, S3]; S2 -> S3
        # resolve S1 -> S2 because it is only one path to S2
        single_incoming_edge.resolved!

        resolved_not_visited_vertexes << single_incoming_edge.to

        current_chain = single_incoming_chains.detect { |chain| chain.first == single_incoming_edge.to || chain.last == single_incoming_edge.from }
        if current_chain
          current_chain.replace(
            if current_chain.first == single_incoming_edge.to
              current_chain.unshift(single_incoming_edge.from)
            else
              current_chain.push(single_incoming_edge.to)
            end
          )
        else
          single_incoming_chains << [single_incoming_edge.from, single_incoming_edge.to]
        end
      end

      single_incoming_chains.each do |chain|
        chain.flat_map { |vertex| vertex.outcoming_edges.to_a }.group_by(&:to).each_value do |outcoming_edges|
          next if outcoming_edges.size < 2

          # S1 -> [S2, S3]; S2 -> S3
          # drops S1 -> S3, because S1 -> S2 resolved as only one path and S3 is reachable from S2
          outcoming_edges[0..outcoming_edges.size - 2].each(&:dropped!)
        end
      end

      current_vertexes = input_vertexes
      visited_vertexes = []
      loop do
        current_following_vertexes = current_vertexes.flat_map { |vertex| vertex.outcoming_edges.map(&:to) }.uniq - visited_vertexes

        if current_following_vertexes.size > 1
          reachable_vertexes = resolved_not_visited_vertexes.flat_map { |vertex| vertex.outcoming_edges.map(&:to) }.uniq
          break if reachable_vertexes.empty?

          current_following_vertexes -= reachable_vertexes
        end

        current_vertexes.each do |from_vertex|
          from_vertex.outcoming_edges.each do |edge|
            next if edge.resolved?

            if current_following_vertexes.include?(edge.to)
              edge.resolved! if current_following_vertexes.size == 1
            elsif resolved_not_visited_vertexes.include?(edge.to)
              edge.dropped!
            end
          end
        end

        current_vertexes = current_following_vertexes
        resolved_not_visited_vertexes -= current_following_vertexes
        visited_vertexes += current_vertexes

        break if current_vertexes.empty?
      end
    end

    def array_wrap(value)
      if value.nil?
        [nil]
      else
        Array.wrap(value)
      end
    end

  end
end
