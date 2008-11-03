module Rspec::Rails::Macros::Views
  module ExampleGroupMethods
    
    def it_should_have_tag_for(name, tag)
      klass = self.described_type
      it "should have a #{name}" do
        do_act!
        evalled_tag = eval("\"#{tag}\"")
        response.should have_tag(evalled_tag)
      end
    end  
  end
  
  def self.included(receiver)
    receiver.extend ExampleGroupMethods
  end
end
