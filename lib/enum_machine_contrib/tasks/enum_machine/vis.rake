# frozen_string_literal: true

namespace :enum_machine do
  desc 'Visualize graph for enum_machine attribute with enum_machine:vis[Order::STATE]'
  task :vis, [:attr] => :environment do |_t, args|
    require 'ruby-graphviz'
    require 'fileutils'

    FileUtils.mkdir_p('tmp')

    enum_machine = args[:attr].constantize.machine
    enum_machine.singleton_class.include(EnumMachineContrib::HasDecisionTree)

    file_path = "./tmp/#{enum_machine.base_klass.name.demodulize.underscore}.png"
    enum_machine.decision_tree.visualize.output(png: file_path)

    puts <<~TEXT
      Rendered to #{file_path}, open in browser with:#{' '}
      xdg-open file://#{File.expand_path(file_path)}
    TEXT
  end
end
