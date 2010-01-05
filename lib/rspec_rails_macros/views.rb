module Rspec::Rails::Macros::Views
  module ExampleGroupMethods
    
    def it_should_have_tag_for(name, tag, tag_content = nil)
      klass = self.described_type
      it "should have a tag for #{name}" do
        do_act!
        evalled_tag = eval("\"#{tag}\"")
        response.should have_tag(evalled_tag, eval("\"#{tag_content}\""))
      end
    end  
  end
  
  def self.included(receiver)
    receiver.extend ExampleGroupMethods
  end
end
