# frozen_string_literal: true

require 'enum_machine'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/array/wrap'

require 'enum_machine_contrib/version'
require 'enum_machine_contrib/railtie' if defined?(Rails::Railtie)
require 'enum_machine_contrib/enum_machine/errors'

module EnumMachineContrib

  autoload :HasDecisionTree, 'enum_machine_contrib/has_decision_tree'
  autoload :DecisionGraph, 'enum_machine_contrib/decision_graph'
  autoload :DecisionTree, 'enum_machine_contrib/decision_tree'
  autoload :Vertex, 'enum_machine_contrib/vertex'
  autoload :Edge, 'enum_machine_contrib/edge'

end
