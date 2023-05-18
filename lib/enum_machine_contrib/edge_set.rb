# frozen_string_literal: true

module EnumMachineContrib
  class EdgeSet < Set

    attr_accessor :with_dropped

    def initialize(*)
      @with_dropped = Set.new
      super
    end

    def add(value)
      @with_dropped << value
      super
    end

  end
end
