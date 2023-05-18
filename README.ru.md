# Расширения EnumMachine 

Репозиторий содержит дополнение к [enum_machine](https://github.com/corp-gp/enum_machine), которое позволяет генерировать графическое представление графа состояний. Для отображения используется open-source решение [Graphviz](https://graphviz.org/).

## Установка

При использовании bundler добавить в Gemfile:

    $ bundle add enum_machine-contrib --group "development"

Или установить gem в систему:

    $ gem install enum_machine-contrib

Установку [GraphViz](https://graphviz.org/) смотрите в соответствующей [инструкции](https://graphviz.org/download/)

## Использование

Предположим, имеется AR-модель `Order` с машиной состояний, заданной [enum_machine](https://github.com/corp-gp/enum_machine)

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

Графическое представление графа (`state`) можно получить rake-командой:

    $ bundle exec rake enum_machine:vis[Order::STATE]

Результатом будет файл `tmp/order.png`:

![states.png](docs/states.png?raw=true "states")

## Дерево решения графа

Граф состояний представляется из себя направленный и возможно циклический граф, из начальной вершины которого можно попасть в одну из конечных. При сложных взаимосвязях даже графическое представление становится нагруженным для восприятия, особенно при наличии [зацикленных вершин](https://ru.wikipedia.org/wiki/%D0%A6%D0%B8%D0%BA%D0%BB_(%D0%B3%D1%80%D0%B0%D1%84)). Поэтому помимо ребер графа на рисунке выше имеется дополнительная разметка. Красными линиями отмечено дерево решения, в котором вершины соединены в [топологическом порядке](https://ru.wikipedia.org/wiki/%D0%A2%D0%BE%D0%BF%D0%BE%D0%BB%D0%BE%D0%B3%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B0%D1%8F_%D1%81%D0%BE%D1%80%D1%82%D0%B8%D1%80%D0%BE%D0%B2%D0%BA%D0%B0). Простыми словами, требуется найти такой порядок вершин, в котором все ребра графа ведут из более ранней вершины в более позднюю.

Алгоритмы топологической сортировки для ориентированного ациклического графа известны. В ядре `ruby` есть встроенный модуль [TSort](https://ruby-doc.org/stdlib-3.0.0/libdoc/tsort/rdoc/TSort.html), использующй, в частности, алгоритм Тарьяна. `RubyOnRails` применяет топологическую сортировку для инициализации приложения. Каждый `Railtie` должен быть загружен не раньше, чем будут загружены все его зависимости.

Для циклического графа топологическая сортировка невозможна. На практике state-машина вряд ли будет представлять из себя полностью цикличный граф, где все вершины связаны со всеми. Скорее возможны островки [компонент сильной связности](https://ru.wikipedia.org/wiki/%D0%9A%D0%BE%D0%BC%D0%BF%D0%BE%D0%BD%D0%B5%D0%BD%D1%82%D0%B0_%D1%81%D0%B8%D0%BB%D1%8C%D0%BD%D0%BE%D0%B9_%D1%81%D0%B2%D1%8F%D0%B7%D0%BD%D0%BE%D1%81%D1%82%D0%B8). Это допущение позволяет сделать первое упрощение задачи построения дерева графа. Ищем в графе компоненты сильной связности, заменяем их на комбинированную вершину, а затем строим топологическую сортировку для комбинированных вершин.

![strongly_connected_component.png](docs/strongly_connected_component.png?raw=true "strongly connected component")

В общем случае с циклическим подграфом сделать ничего не получится. Однако некоторые частные (но довольно частые), все же позволяют доопределить дерево решения. 

### Вершины с единственным входом

Среди вершин зацикленного графа могут оказаться те, которые имеют единственное входящее ребро. Это означает, что это ребро неминуемо должно появится в дереве решения. Следствием является несколько моментов:

1) В вершину S2 есть едиственный путь из S1, из обеих вершин можно попасть в S4. Вершина S1 предшествует S2, значит более поздней зависимостью S4 будет S2, а переход S1 -> S4 не должен попасть в дерево решения. 

![move_forward_single.png](docs/move_forward_single.png?raw=true "move forward single")

2) Это также справедливо для цепочек вершин. Если из S1 и S4 можно попасть в S5, то S1 -> S5 опять же можно игнорировать. Одноименные выходы "перетекают" в конец цепочки.

![move_forward_chain.png](docs/move_forward_chain.png?raw=true "move forward chain")

3) У первой вершины цепочки может быть несколько возможных входов. В некоторых случаях возможно определить, какой из них попадет в дерево решения. Если входящие ребра включают в себя достижимые в дальнейшем по цепочке вершины, можно попробовать их отбросить. Если после этого остается единственный вход - включаем его в дерево решения. 

![resolve_backward.png](docs/resolve_backward.png?raw=true "resolve backward")

### bottleneck-вершины

Иногда в сильной компоненте графа может встретиться особый случай вершины, минуя которую, невозможно попасть из одной части графа в другую, все ребра сходятся через эту узловую точку. У этой вершины могут быть как прямые, так и обратные ребра, однако дерево решение должно пройти через эту вершину строго в направлении от входа. Для обнаружения такого варианта можно поочередно удалять вершины, проверяя достижимость всех вершин компоненты. Если в какой-то момент обнаружили, что часть подграфа недоступна - делим его по этой bottleneck-вершине (S5): 

![bottleneck.png](docs/bottleneck.png?raw=true "bottleneck")

4) Отбрасываем входящие ребра, которые ведут из второй половины подграфа, недостижимой от входа.

![bottleneck_incoming.png](docs/bottleneck_incoming.png?raw=true "bottleneck incoming")

5) Из узловой вершины некоторые исходящие ребра будут вести в первую половину подграфа. По аналогии с вершинами с единственным входом, одноименные выходы "перетекают" на bottleneck-вершину. 

![bottleneck_outgoing.png](docs/bottleneck_outgoing.png?raw=true "bottleneck outgoing")

После применения описанных приемов часть дуг из подграфа удаляются и можно попробовать вновь поискать компоненты сильной связности. Алгоритм можно повторять до тех пор, пока не перестанет изменяться сложность графа (сумма активных ребер). Также для облегчения восприятия можно объединить вершины, которые имеют одинаковые входы/выходы и объединить двунаправленные ребра в одну. В результате получаем такую картинку:

![bottleneck_resolved.png](docs/bottleneck_resolved.png?raw=true "bottleneck resolved")

## Использованная литература

1) Джефф Эриксон, Алгоритмы / пер. с англ. А.  В. Снастина. – М.: ДМК Пресс, 2023.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/enum_machine-contrib. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EnumMachine::Contrib project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/enum_machine-contrib/blob/master/CODE_OF_CONDUCT.md).
