# BlockStackModel

BlockStack Model is an ORM that aims to make persistence as easy as possible for developers. Model performs similar functionality to other ORMs such as Active Record, but adds in capabilities meant to truly bridge the gap between the database code and your source code.

Unlike many other similar libraries, models are declared using a mixin, not through inheritance. This means you can write your objects as plain old ruby (POR) and then inject the persistence layer. This avoids having to deal with two versions of objects; one that represents the data in your database and an actual object that performs actions based on those properties.

BlockStack Model is part of the larger BlockStack web framework but can be used on its own to add persistence to any application.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'block_stack_model'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install block_stack_model

## Usage

```ruby
require 'block_stack/model'
```

More to come...

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/block_stack_model. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the BlockStackModel project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/block_stack_model/blob/master/CODE_OF_CONDUCT.md).
