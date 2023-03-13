[![Build](https://github.com/corp-gp/enum_machine-contrib/workflows/Build/badge.svg)](https://github.com/corp-gp/enum_machine-contrib/actions)

# EnumMachine extensions and tools

This repository contains extensions and development tools for the [enum_machine](https://github.com/corp-gp/enum_machine)

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add enum_machine-contrib ruby-graphviz --group "development"

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install enum_machine-contrib ruby-graphviz

The gem depends on [GraphViz](https://graphviz.org/)). See the [installation notes](https://graphviz.org/download/)

## Usage

Suppose we have `Order` AR-model with the state machine specified by [enum_machine](https://github.com/corp-gp/enum_machine)

`config/initializers/enum_machine.rb`
```ruby
require 'enum_machine_contrib/has_decision_tree'
```

`app/models/order.rb`
```ruby
class Order < ActiveRecord::Base
  enum_machine :state, %w[s0 s1 s2 s3 s3.1 s3.2 s4 s4.1 s4.2 s5 s6 s6.1 s6.2 s7 s8 s9 s10 s11] do
    transitions(
      nil    => %w[s0],
      's0'   => %w[s1],
      's1'   => %w[s2],
      's2'   => %w[s3],
      's3'   => %w[s3.1 s3.2 s4],
      's3.1' => %w[s1],
      's3.2' => %w[s1],
      's4'   => %w[s4.1 s4.2 s5],
      's4.1' => %w[s2],
      's4.2' => %w[s2],
      's5'   => %w[s6.1 s6.2],
      's6.2' => %w[s7],
      's6.1' => %w[s8],
      's8'   => %w[s9],
      's9'   => %w[s10],
      's7'   => %w[s11],
      's10'  => %w[s11],
    )
  end
end
```

The gem allows you to get a visual representation of the graph of state transitions.

```ruby
Order::STATE.machine.decision_tree.visualize.output(png: 'states.png')
```

You will see:

![states.png](states.png?raw=true "states")

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/enum_machine-contrib. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EnumMachine::Contrib project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).
