# frozen_string_literal: true

module EnumMachineContrib

  Vertex =
    Struct.new(:value) do
      attr_accessor :mode, :level
      attr_reader :incoming_edges, :outgoing_edges

      VERTEX_MODES = %i[pending dropped combined cycled].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

      def initialize(value)
        self.value = value

        @incoming_edges = EdgeSet.new
        @outgoing_edges = EdgeSet.new

        @resolved = false
        pending!
      end

      VERTEX_MODES.each do |mode|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          # def combined!
          #   self.mode = :combined
          # end
          # def combined?
          #   self.mode == :combined
          # end

          def #{mode}!
            self.mode = :#{mode}
          end
          def #{mode}?
            self.mode == :#{mode}
          end
        RUBY
      end

      def active?
        !dropped?
      end

      def resolved!
        @resolved = true
      end

      def resolved?
        @resolved == true
      end

      def dropped!
        return if dropped?

        self.mode = :dropped

        incoming_edges.each(&:dropped!)
        outgoing_edges.each(&:dropped!)
      end

      def edge_to(to_vertex)
        new_edge = Edge.new(self, to_vertex)

        outgoing_edges.add(new_edge)
        to_vertex.incoming_edges.add(new_edge)

        new_edge
      end

      def self.replace!(replacing_vertexes)
        new_vertex = Vertex[replacing_vertexes.flat_map(&:value)]

        replacing_vertexes.each do |replacing_vertex|
          replacing_vertex.incoming_edges.each do |edge|
            next if replacing_vertexes.include?(edge.from)

            edge.from.edge_to(new_vertex)
          end

          replacing_vertex.outgoing_edges.filter_map do |edge|
            next if replacing_vertexes.include?(edge.to)

            new_vertex.edge_to(edge.to)
          end

          replacing_vertex.dropped!
        end

        new_vertex
      end

      def inspect
        "<Vertex [#{mode}]#{'[resolved]' if resolved?} value=#{value || 'nil'}>"
      end
    end

end
