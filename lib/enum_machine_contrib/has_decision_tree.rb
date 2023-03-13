# frozen_string_literal: true

module EnumMachineContrib
  module HasDecisionTree

    def decision_tree
      start_values = @transitions.keys - @transitions.values.flatten.uniq
      raise EnumMachine::InvalidTransitionGraph, 'There is no start value' if start_values.empty?
      raise EnumMachine::InvalidTransitionGraph, 'Multiple graphs detected' if start_values.size > 1

      DecisionGraph.new(@transitions).decision_tree
    end

  end
end

module EnumMachine

  class Machine

    include EnumMachineContrib::HasDecisionTree

  end

  class InvalidTransitionGraph < StandardError; end

end
