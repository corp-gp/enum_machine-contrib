# EnumMachine extensions

The repository contains an extension to [enum_machine](https://github.com/corp-gp/enum_machine) that allows you to generate a graphical representation of the state graph. The open-source solution [Graphviz](https://graphviz.org/) is used for the display.

**Описание доступно на [русском языке](README.ru.md)**

## Setup.

Install the gem and add to the application's Gemfile by executing:

    $ bundle add enum_machine-contrib --group "development"

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install enum_machine-contrib

For installation of [GraphViz](https://graphviz.org/) see corresponding [instructions](https://graphviz.org/download/)

## Usage

Suppose there is an AR model `Order` with a state machine specified by [enum_machine](https://github.com/corp-gp/enum_machine)

`app/models/order.rb`
```ruby
class Order < ActiveRecord::Base
  enum_machine :state, %w[created wait_for_send billed need_to_pay paid cancelled shipped lost received closed] do
    transitions(
      nil                                          => 'created',
      'created'                                    => %w[wait_for_send billed],
      'wait_for_send'                              => 'billed',
      %w[created billed wait_for_send]             => 'need_to_pay',
      %w[created billed wait_for_send need_to_pay] => %w[paid cancelled],
      %w[billed need_to_pay paid]                  => 'shipped',
      %w[paid shipped]                             => 'lost',
      %w[billed need_to_pay paid shipped]          => 'received',
      %w[paid shipped received]                    => 'closed',
    )
  end
end
```

You can get graphical representation of graph (`state`) with rake command:

    $ bundle exec rake enum_machine:vis[Order::STATE]

The result will be the file `tmp/order.png`:

![states.png](docs/states.png?raw=true "states")

## The decision tree

A graph of states appears as a directed and possibly cyclic graph, from whose initial node you can get to one of the final nodes. With complex interrelationships even the graphical representation becomes a load to perceive, especially with [cycled vertices](https://en.wikipedia.org/wiki/Cycle_(graph_theory)). Therefore, there is additional markup in the figure above. The red lines mark the decision tree in which vertices are connected in [topological order](https://en.wikipedia.org/wiki/Topological_sorting). In simple words, we need to find an order of vertices in which all edges of the graph lead from an earlier vertex to a later one.

Algorithms of topological sorting for oriented acyclic graph are well known. There is a built-in module [TSort](https://ruby-doc.org/stdlib-3.0.0/libdoc/tsort/rdoc/TSort.html) in the `ruby` kernel which uses, among others, the Tarjan algorithm. The `RubyOnRails` module uses topological sorting to initialize the application. Each `Railtie` must not be loaded before all its dependencies are loaded.

Topological sorting is not possible for a cyclic graph. In practice, the state-machine is unlikely to be a fully cyclic graph where all vertices are connected to all vertices. Rather possible some related [strongly connected components](https://en.wikipedia.org/wiki/Strongly_connected_component). This assumption allows us to make the first simplification of the decision tree problem. We look for strong connected components in the graph, replace them with a combined vertex, and then construct a topological sort for the combined vertices.

![strongly_connected_component.png](docs/strongly_connected_component.png?raw=true "strongly connected component")

In the general case, nothing can be done with a cyclic subgraph. However, some special cases (but quite frequent) do allow you to further define the decision tree.

### Vertices with a single input

Among the vertices of a cyclic graph there may be vertices that have a single input edge. This means that this edge must inevitably appear in the decision tree. The consequence is several things:

1) There is a single path to a vertex S2 from S1, from both vertices you can get to S4. The vertex S1 precedes S2, so the later dependency of S4 will be S2, and the transition S1 -> S4 should not get into the decision tree.

![move_forward_single.png](docs/move_forward_single.png?raw=true "move forward single")

2) This is also true for chains of vertices. If you can get from S1 and S4 to S5, then S1 -> S5 again can be ignored. The same-named outputs "flow" to the end of the chain.

![move_forward_chain.png](docs/move_forward_chain.png?raw=true "move forward chain")

3) The first vertex of a chain can have several possible inputs. In some cases it is possible to determine which of them will end up in the decision tree. If the incoming edges include vertices that can be reached later in the chain, you can try to discard them. If this leaves only one input, include it in the decision tree.

![resolve_backward.png](docs/resolve_backward.png?raw=true "resolve backward")

### bottleneck vertices

Sometimes a strong component may have a special case of a node that cannot be passed from one part of the graph to another, all the edges converge through this node point. This vertex can have both forward and backward edges, but the decision tree must pass through this node strictly in the direction from the input. To detect such case, you can remove vertices one by one, checking the reachability of all vertices in subgraph. If at some point we find that part of the subgraph is inaccessible - we divide it by this bottleneck vertex (S5):

![bottleneck.png](docs/bottleneck.png?raw=true "bottleneck")

4) Discard incoming edges that lead from the second half of the subgraph, unreachable from the input.

![bottleneck_incoming.png](docs/bottleneck_incoming.png?raw=true "bottleneck incoming")

5) From the node vertex some outgoing edges will lead to the first half of the subgraph. By analogy with vertices with a single input, the same-named outputs "flow" to the bottleneck vertex.

![bottleneck_outgoing.png](docs/bottleneck_outgoing.png?raw=true "bottleneck outgoing")

After applying the described techniques, some of the arcs from the subgraph are removed and you can try again to look for strong connectivity components. The algorithm can be repeated until the complexity of the graph (count of active edges) does not change. Also for easier perception we can combine vertices that have the same inputs/outputs and merge bi-directional edges into one. The result is the following picture:

![bottleneck_resolved.png](docs/bottleneck_resolved.png?raw=true "bottleneck resolved")

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/enum_machine-contrib. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EnumMachine::Contrib project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).
