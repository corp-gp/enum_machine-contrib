# frozen_string_literal: true

module EnumMachineContrib

  Vertex =
    Struct.new(:value) do
      attr_accessor :mode, :incoming_edges, :outcoming_edges, :level

      VERTEX_MODES = %i[plain dropped combined cycled].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

      def initialize(value)
        self.value = value
        self.outcoming_edges = Set.new
        self.incoming_edges = Set.new

        plain!
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

      def dropped!
        return if dropped?

        self.mode = :dropped

        incoming_edges.each(&:dropped!)
        outcoming_edges.each(&:dropped!)
      end

      def add_edge(to_vertex)
        new_edge = Edge.new(self, to_vertex)

        outcoming_edges << new_edge
        to_vertex.incoming_edges << new_edge

        new_edge
      end

      def self.replace!(replacing_vertexes)
        new_vertex = Vertex[replacing_vertexes.flat_map(&:value)]

        replacing_vertexes.each do |replacing_vertex|
          replacing_vertex.incoming_edges.each do |edge|
            next unless edge.active?
            next if replacing_vertexes.include?(edge.from)

            edge.from.add_edge(new_vertex)
          end

          replacing_vertex.outcoming_edges.filter_map do |edge|
            next unless edge.active?
            next if replacing_vertexes.include?(edge.to)

            new_vertex.add_edge(edge.to)
          end

          replacing_vertex.dropped!
        end

        new_vertex
      end

      def inspect
        "<Vertex [#{mode}] value=#{value || 'nil'}>"
      end
    end

end
