module Rspec::Rails::Macros::Models
  module ExampleGroupMethods
    
    def it_should_have_association(assoc_name, assoc_type)
      klass = self.described_type
      it "should have a #{assoc_type} association #{assoc_name}" do
        klass.reflect_on_association(assoc_name).macro.should == assoc_type
      end
    end
  end

  def self.included(receiver)
    receiver.extend         ExampleGroupMethods
  end
end


