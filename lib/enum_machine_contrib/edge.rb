# frozen_string_literal: true

module EnumMachineContrib

  Edge =
    Struct.new(:from, :to) do
      attr_accessor :mode

      EDGE_MODES = %i[pending resolved dropped].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

      def initialize(from, to)
        self.from = from
        self.to   = to

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

      def resolved!
        self.mode = :resolved

        to.incoming_edges.each do |edge|
          edge.dropped! unless edge == self
        end

        to.outcoming_edges.detect { |edge| edge.to == from }&.dropped!

        to.resolved!
      end

      def inspect
        "<Edge [#{mode}] #{from.inspect} -> #{to.inspect}>"
      end
    end

end
