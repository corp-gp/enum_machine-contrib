# frozen_string_literal: true

require 'rspec'

RSpec.describe EnumMachineContrib::DecisionGraph do
  describe '#decision_tree' do
    it 'builds resolved decision tree' do
      g = described_class.new(
        nil           => %w[s0],
        's0'          => %w[s1],
        's1'          => %w[s2],
        's2'          => %w[s3],
        's3'          => %w[s3.1 s3.2 s4],
        's3.1'        => %w[s1],
        's3.2'        => %w[s1],
        's4'          => %w[s4.1 s4.2 s5],
        's4.1'        => %w[s2],
        's4.2'        => %w[s2],
        's5'          => %w[s6.1 s6.2],
        's6.2'        => %w[s7],
        's6.1'        => %w[s8],
        's8'          => %w[s9],
        's9'          => %w[s10],
        's7'          => %w[s11],
        's10'         => %w[s11],
      )
      expect(g.decision_tree.resolved).to eq({
        [nil] => [["s0"]],
        ["s0"] => [["s1"]],
        ["s1"] => [["s2"]],
        ["s2"] => [["s3"]],
        ["s3"] => [["s4"], ["s3.1", "s3.2"]],
        ["s3.1", "s3.2"] => [],
        ["s4"] => [["s5"], ["s4.1", "s4.2"]],
        ["s4.1", "s4.2"] => [],
        ["s5"] => [["s6.1"], ["s6.2"]],
        ["s6.1"] => [["s8"]],
        ["s6.2"] => [["s7"]],
        ["s7"] => [],
        ["s8"] => [["s9"]],
        ["s9"] => [["s10"]],
        ["s10"] => [["s11"]],
        ["s11"] => [],
      })
    end
  end
end
