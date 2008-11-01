module Rspec::Rails::Macros::Controller
  module ExampleMethods
    def do_action
      # Use if there is some common method I want to use here
    end
  end

  module ExampleGroupMethods
    
    def act(&block)
      @acting_block = block
    end
    
    def acting_block
      @acting_block
    end
    
    def it_should_assign(variable_name, value = nil, &block)
      it "should assign #{variable_name}" do
        do_act!
        if value
          assigns[variable_name].should == value
        elsif block
          assigns[variable_name].should == instance_eval(&block)
        else
          assigns[variable_name].should_not be_nil
        end
      end
    end
    
    def it_should_be_success
      it 'should be a success' do
        do_act!
        response.should be_success
      end
    end

    def it_should_be_forbidden
      it 'should be forbidden' do
        do_act!
        response.should be_forbidden
      end
    end
    
    def it_should_render_template(template)
      it "should render the #{template} template" do
        do_act!
        response.should render_template(template)
      end      
    end
    
    def it_should_redirect_to(&route)
      it "should redirect to #{route.inspect}" do
        do_act!
        response.should redirect_to(instance_eval(&route))
      end
    end
    
    def it_should_facebook_redirect_to(&route)
      if route.respond_to?(:to_ruby)
        hint = route.to_ruby.gsub(/(^proc \{)|(\}$)/, '').strip
      end
      it "should redirect to #{(hint || route).inspect}" do
        do_act!
        assert_facebook_redirect_to instance_eval(&route)
      end
    end
    
    def it_should_require_facebook_installation(&act)
      describe 'not logged into facebook, or the app not installed' do
        it 'should require facebook app installation' do
          instance_eval(&act)
          assert_facebook_redirect_to Facebooker::Session.create.install_url 
        end
      end
    end
    
    def it_should_expect(message, &block)
      it "should #{message}" do
        instance_eval(&block)
        do_act!
      end
    end
    alias_method :it_should_expect_to, :it_should_expect
  end

  def self.included(receiver)
    receiver.extend         ExampleGroupMethods
    receiver.send :include, ExampleMethods
  end
end