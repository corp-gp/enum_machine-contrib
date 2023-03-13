# frozen_string_literal: true

module EnumMachine

  class Machine

    include EnumMachineContrib::HasDecisionTree

  end

  class InvalidTransitionGraph < StandardError; end

end
