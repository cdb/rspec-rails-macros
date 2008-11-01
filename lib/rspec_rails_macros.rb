require 'rspec_rails_macros/behaviours'
require 'rspec_rails_macros/controllers'
require 'rspec_rails_macros/models'

Spec::Runner.configuration.include Rspec::Rails::Macros::Behaviors
Spec::Runner.configuration.include Rspec::Rails::Macros::Controller, :type => :controllers
Spec::Runner.configuration.include Rspec::Rails::Macros::Models, :type => :models
