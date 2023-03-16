# frozen_string_literal: true

require 'rspec'

RSpec.describe EnumMachineContrib::HasDecisionTree do
  let(:extended_enum_machine) do
    enum_machine = EnumMachine::Machine
    enum_machine.include(described_class)
    enum_machine
  end

  describe '#decision_tree' do
    it 'fails for cycled graph' do
      m = extended_enum_machine.new(%w[s1 s2])
      m.transitions('s1' => 's2', 's2' => 's1')
      expect { m.decision_tree }
        .to raise_error(EnumMachine::InvalidTransitionGraph)
    end

    it 'fails for multiple trees' do
      m = extended_enum_machine.new(%w[s1 s2 a1 a2])
      m.transitions('s1' => 's2', 'a1' => 'a2')
      expect { m.decision_tree }
        .to raise_error(EnumMachine::InvalidTransitionGraph)
    end
  end
end
