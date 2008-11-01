begin
  require 'ruby2ruby'
rescue LoadError
  # no pretty example descriptions for you
end

module Rspec
  module Rails
    module Macros
      module Behaviors
        def do_act!
          if self.respond_to?(:act!)
            act!
          else
            instance_eval &self.class.acting_block
          end
        end
      end
    end
  end
end
