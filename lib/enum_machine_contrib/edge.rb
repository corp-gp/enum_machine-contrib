# frozen_string_literal: true

module EnumMachineContrib

  Edge =
    Struct.new(:from, :to) do
      attr_accessor :mode

      EDGE_MODES = %i[pending dropped].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

      def initialize(from, to)
        self.from = from
        self.to   = to

        @resolved = false
        pending!
      end

      EDGE_MODES.each do |mode|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          # def resolved!
          #   self.mode = :resolved
          # end
          # def resolved?
          #   self.mode == :resolved
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
        self.mode = :dropped

        to.incoming_edges.delete(self)
        from.outgoing_edges.delete(self)
      end

      def resolved?
        @resolved == true
      end

      def resolved!
        @resolved = true

        to.incoming_edges.each do |edge|
          edge.dropped! unless edge == self
        end

        to.outgoing_edges.detect { |edge| edge.to == from }&.dropped!

        to.resolved!
      end

      def inspect
        "<Edge [#{mode}]#{'[resolved]' if resolved?} #{from.inspect} -> #{to.inspect}>"
      end
    end

end
