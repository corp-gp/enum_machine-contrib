# frozen_string_literal: true

require 'rspec'

require 'enum_machine_contrib/has_decision_tree'

RSpec.describe EnumMachineContrib::HasDecisionTree do
  describe '#decision_tree' do
    it 'fails for cycled graph' do
      m = EnumMachine::Machine.new(%w[s1 s2])
      m.transitions('s1' => 's2', 's2' => 's1')
      expect { m.decision_tree }
        .to raise_error(EnumMachine::InvalidTransitionGraph)
    end

    it 'fails for multiple trees' do
      m = EnumMachine::Machine.new(%w[s1 s2 a1 a2])
      m.transitions('s1' => 's2', 'a1' => 'a2')
      expect { m.decision_tree }
        .to raise_error(EnumMachine::InvalidTransitionGraph)
    end
  end
end
