# frozen_string_literal: true

require 'tsort'

module EnumMachineContrib
  class DecisionTree < Hash

    include TSort

    def tsort_each_child(node, &_block)
      fetch(node).outcoming_edges.each { |edge| yield(edge.to.value) }
    end

    def tsort_each_node(&_block)
      each_value { |vertex| yield(vertex.value) if vertex.active? }
    end

    def self.wrap(hsh)
      vertex_by_value = {}

      hsh.each do |from_value, to_value_list|
        vertex_by_value[from_value] ||= Vertex[from_value]
        from_vertex = vertex_by_value[from_value]

        to_value_list.each do |to_value|
          vertex_by_value[to_value] ||= Vertex[to_value]
          from_vertex.edge_to(vertex_by_value[to_value])
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

        resolved_hash[vertex.value] = vertex.outcoming_edges.map { |edge| edge.to.value }
      end

      resolved_hash
    end

    ACTIVE_EDGE_STYLE   = 'color=red penwidth=2'
    INACTIVE_EDGE_STYLE = 'color=grey'

    CLEAN_ID = proc { |s| s.gsub(/[^[[:alnum:]]]/, '_') }

    def as_dot # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
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
              { id: vertex.value[0].then(&CLEAN_ID), cluster_id: "cluster_#{cluster_id}" }
            else
              { id: vertex.value.join.then(&CLEAN_ID), label: vertex.value.join }
            end,
          ]
        }
          .to_h

      vertexes_by_level = visible_vertexes.filter(&:level).sort_by(&:level).group_by(&:level)
      node_ranks =
        vertexes_by_level.filter_map do |_level, vertexes_same_rank|
          vertex_ids = vertexes_same_rank.filter_map { |vertex| nodes[vertex][:id] if !vertex.cycled? && !vertex.combined? }
          next if vertex_ids.empty?

          "{ rank=same #{vertex_ids.join(' ')} }"
        end

      node_labels = plain_vertexes.map { |vertex| "#{nodes[vertex][:id]} [label=\"#{nodes[vertex][:label]}\"]" }

      clusters =
        cycled_vertexes.map do |vertex|
          "subgraph #{nodes[vertex][:cluster_id]} { color=blue style=dashed #{vertex.value.join(' ')} }"
        end

      resolved_not_active_edges = []

      pending_edges =
        visible_vertexes.flat_map do |vertex|
          vertex.incoming_edges.with_dropped.filter_map do |edge|
            if (!edge.from.combined? && (combined_values & edge.from.value).any?) ||
               (!edge.to.combined? && (combined_values & edge.to.value).any?)
              next
            end

            if !edge.active? && (edge.from.combined? || edge.to.combined? || edge.from.cycled? || edge.to.cycled?)
              next
            end

            if edge.resolved? && !edge.active?
              resolved_not_active_edges << edge
            end

            edge
          end
        end

      resolved_not_active_edges.each do |current_edge|
        pending_edges.delete_if do |edge|
          (edge.from.cycled? && (edge.from.value & current_edge.from.value).any? && edge.to == current_edge.to) ||
            (edge.from == current_edge.from && edge.to.cycled? && (edge.to.value & current_edge.to.value).any?)
        end
      end

      transitions = []

      until pending_edges.empty?
        current_edge = pending_edges.shift

        attrs = []

        if current_edge.resolved?
          attrs << ACTIVE_EDGE_STYLE
          attrs << "ltail=#{nodes[current_edge.from][:cluster_id]}" if current_edge.from.cycled?
          attrs << "lhead=#{nodes[current_edge.to][:cluster_id]}" if current_edge.to.cycled?
        else
          attrs << INACTIVE_EDGE_STYLE
        end

        unless current_edge.resolved?
          reverse_edge = pending_edges.detect { |edge| edge.from == current_edge.to && edge.to == current_edge.from }

          if reverse_edge && !reverse_edge.resolved?
            pending_edges.delete(reverse_edge)
            attrs << 'dir=both'
          end
        end

        transitions << "#{nodes[current_edge.from][:id]} -> #{nodes[current_edge.to][:id]} [#{attrs.join(' ')}]"
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
