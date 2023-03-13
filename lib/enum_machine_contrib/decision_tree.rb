# frozen_string_literal: true

require 'tsort'

module EnumMachineContrib
  class DecisionTree < Hash

    include TSort

    def tsort_each_child(node, &block)
      fetch(node).outcoming_edges.each { |edge| block.call(edge.to.value) if edge.active? }
    end
    def tsort_each_node(&block)
      each_value { |vertex| block.call(vertex.value) if vertex.active? }
    end

    def self.wrap(hsh)
      vertex_by_value = {}

      hsh.each do |from_value, to_value_list|
        vertex_by_value[from_value] ||= Vertex[from_value]
        from_vertex = vertex_by_value[from_value]

        to_value_list.each do |to_value|
          vertex_by_value[to_value] ||= Vertex[to_value]
          from_vertex.add_edge(vertex_by_value[to_value])
        end
      end

      DecisionTree[vertex_by_value]
    end

    def resolve!
      strongly_connected_components.each do |strongly_connected_values|
        next if strongly_connected_values.size < 2

        clusterize_strong_component!(values_at(*strongly_connected_values))
      end

      values_topological_sorted = tsort.reverse
      vertexes_topological_sorted = values_at(*values_topological_sorted)

      start_vertex = vertexes_topological_sorted.shift
      start_vertex.level = 0

      visited_vertexes = [].unshift(start_vertex)

      vertexes_topological_sorted.each do |to_vertex|
        current_edge = nil

        visited_vertexes.each do |vertex|
          current_edge = fetch(vertex.value).outcoming_edges.detect { |edge| edge.to == to_vertex }
          break if current_edge
        end

        to_vertex.level = current_edge.from.level + 1
        current_edge.resolved!

        visited_vertexes.unshift(to_vertex)
      end

      each_value do |vertex|
        vertex.outcoming_edges.each do |edge|
          edge.dropped! unless edge.resolved?
        end
      end
    end

    def resolved
      resolved_hash = {}

      each_value do |vertex|
        next unless vertex.active?

        resolved_hash[vertex.value] = vertex.outcoming_edges.filter_map { |edge| edge.to.value if edge.active? }
      end

      resolved_hash
    end

    ACTIVE_EDGE_STYLE   = 'color=red penwidth=2'
    INACTIVE_EDGE_STYLE = 'color=grey'

    CLEAN_ID = proc { |s| s.gsub(/[^[[:alnum:]]]/, '_') }

    def as_dot
      combined_values  = values.filter(&:combined?).flat_map(&:value).to_set
      visible_vertexes = values.reject { |vertex| (combined_values & vertex.value).any? && !vertex.combined? }

      cycled_vertexes, plain_vertexes = visible_vertexes.partition(&:cycled?)

      nodes =
        visible_vertexes
          .map.with_index { |vertex, cluster_id|
          [
            vertex,
            if vertex.value.compact.blank?
              { id: 'null', label: 'nil' }
            elsif vertex.combined?
              { id: vertex.value.map(&CLEAN_ID).join('__'), label: vertex.value.join('/') }
            elsif vertex.cycled?
              { id: vertex.value[0].yield_self(&CLEAN_ID), cluster_id: "cluster_#{cluster_id}" }
            else
              { id: vertex.value.join.yield_self(&CLEAN_ID), label: vertex.value.join }
            end
          ]
        }
          .to_h

      vertexes_by_level = visible_vertexes.filter(&:level).sort_by(&:level).group_by(&:level)
      node_ranks =
        vertexes_by_level.map do |_level, vertexes_same_rank|
          "{ rank=same #{vertexes_same_rank.reject(&:combined?).reject(&:cycled?).map { |vertex| nodes[vertex][:id] }.join(' ')} }"
        end

      node_labels = plain_vertexes.map { |vertex| "#{nodes[vertex][:id]} [label=\"#{nodes[vertex][:label]}\"]" }

      clusters =
        cycled_vertexes.map do |vertex|
          "subgraph #{nodes[vertex][:cluster_id]} { color=blue style=dashed #{vertex.value.join(' ')} }"
        end

      transitions =
        visible_vertexes.flat_map do |vertex|
          vertex.outcoming_edges.filter_map do |edge|
            if (!edge.from.combined? && (combined_values & edge.from.value).any?) ||
              (!edge.to.combined? && (combined_values & edge.to.value).any?)
              next
            end

            attrs = []
            if edge.active?
              attrs << ACTIVE_EDGE_STYLE
              attrs << "ltail=#{nodes[edge.from][:cluster_id]}" if edge.from.cycled?
              attrs << "lhead=#{nodes[edge.to][:cluster_id]}" if edge.to.cycled?
            else
              attrs << INACTIVE_EDGE_STYLE
            end
            "#{nodes[edge.from][:id]} -> #{nodes[edge.to][:id]} [#{attrs.join(' ')}]"
          end
        end

      <<~DOT
        digraph {
          ranksep="1.0 equally"
          compound=true
          #{clusters.join("\n")}
          #{node_labels.join('; ')}
          #{node_ranks.join('; ')}
          #{transitions.join("\n")}
        }
      DOT
    end

    def visualize
      GraphViz.parse_string(as_dot)
    end

    private def clusterize_strong_component!(replacing_vertexes)
      new_vertex = Vertex.replace!(replacing_vertexes)
      new_vertex.cycled!

      self[new_vertex.value] = new_vertex
    end

  end
end
