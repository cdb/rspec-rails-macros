module Rspec::Rails::Macros::Models
  module ExampleGroupMethods
    
    def it_should_have_association(assoc_name, assoc_type)
      klass = self.described_type
      it "should have a #{assoc_type} association #{assoc_name}" do
        klass.reflect_on_association(assoc_name).macro.should == assoc_type
      end
    end
    
    
    # Ensures that the model cannot be saved if one of the attributes listed is not present.
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:blank]</tt>
    #
    # Example:
    #   should_require_attributes :name, :phone_number
    #
    def it_should_require_attributes(*attributes)
      message = get_options!(attributes, :message)
      message ||= DEFAULT_ERROR_MESSAGES[:blank]
      klass = self.described_type

      attributes.each do |attribute|
        describe "requires #{attribute} to be set" do
          assert_bad_value(klass, attribute, nil, message)
        end
      end
    end

    # Ensures that the model cannot be saved if one of the attributes listed is not unique.
    # Requires an existing record
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:taken]</tt>
    # * <tt>:scoped_to</tt> - field(s) to scope the uniqueness to.
    #
    # Examples:
    #   it_should_require_unique_attributes :keyword, :username
    #   it_should_require_unique_attributes :name, :message => "O NOES! SOMEONE STOELED YER NAME!"
    #   it_should_require_unique_attributes :email, :scoped_to => :name
    #   it_should_require_unique_attributes :address, :scoped_to => [:first_name, :last_name]
    #
    def it_should_require_unique_attributes(*attributes)
      message, scope = get_options!(attributes, :message, :scoped_to)
      scope = [*scope].compact
      message ||= DEFAULT_ERROR_MESSAGES[:taken]

      klass = self.described_type

      attributes.each do |attribute|
        attribute = attribute.to_sym
        describe "requires unique value for #{attribute}#{" scoped to #{scope.join(', ')}" unless scope.blank?}" do
          before do
            @existing = klass.find(:first)
          end
          
          it "should have one #{klass} record in the database in order to test" do
            @existing.should_not be_nil
          end

          return if !@existing

          object = klass.new
          existing_value = @existing.send(attribute)

          if !scope.blank?
            scope.each do |s|
              it "should have a #{s} attribute" do
                object.should respond_to(:"#{s}=")
              end
              object.send("#{s}=", @existing.send(s))
            end
          end
          assert_bad_value(object, attribute, existing_value, message)

          # Now test that the object is valid when changing the scoped attribute
          # TODO:  There is a chance that we could change the scoped field
          # to a value that's already taken.  An alternative implementation
          # could actually find all values for scope and create a unique
          # one.
          if !scope.blank?
            scope.each do |s|
              # Assume the scope is a foreign key if the field is nil
              object.send("#{s}=", @existing.send(s).nil? ? 1 : @existing.send(s).next)
              assert_good_value(object, attribute, existing_value, message)
            end
          end
        end
      end
    end  

    # Ensures that the attribute cannot be set on mass update.
    #
    #   it_should_protect_attributes :password, :admin_flag
    #
    def it_should_protect_attributes(*attributes)
      get_options!(attributes)
      klass = self.described_type

      attributes.each do |attribute|
        attribute = attribute.to_sym
        describe "protects #{attribute} from mass updates" do
          protected = klass.protected_attributes || []
          accessible = klass.accessible_attributes || []

          it "should be protected" do
            (protected.include?(attribute.to_s) ||
                (!accessible.empty? && !accessible.include?(attribute.to_s))).should be_true
          end        
        end
      end
    end

    # Ensures that the attribute cannot be changed once the record has been created.
    #
    #   it_should_have_readonly_attributes :password, :admin_flag
    #
    def it_should_have_readonly_attributes(*attributes)
      get_options!(attributes)
      klass = self.described_type

      attributes.each do |attribute|
        attribute = attribute.to_sym
        describe "makes #{attribute} read-only" do
          readonly = klass.readonly_attributes || []

          it "should be read-only" do
            readonly.should include(attribute.to_s)
          end
        end
      end
    end

    # Ensures that the attribute cannot be set to the given values
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:invalid]</tt>
    #
    # Example:
    #   it_should_not_allow_values_for :isbn, "bad 1", "bad 2"
    #
    def it_should_not_allow_values_for(attribute, *bad_values)
      message = get_options!(bad_values, :message)
      message ||= DEFAULT_ERROR_MESSAGES[:invalid]
      klass = self.described_type
      bad_values.each do |v|
        describe "doesn't allow #{attribute} to be set to #{v.inspect}" do
          assert_bad_value(klass, attribute, v, message)
        end
      end
    end

    # Ensures that the attribute can be set to the given values.
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Example:
    #   it_should_allow_values_for :isbn, "isbn 1 2345 6789 0", "ISBN 1-2345-6789-0"
    #
    def it_should_allow_values_for(attribute, *good_values)
      get_options!(good_values)
      klass = self.described_type
      good_values.each do |v|
        describe "allows #{attribute} to be set to #{v.inspect}" do
          assert_good_value(klass, attribute, v)
        end
      end
    end

    # Ensures that the length of the attribute is in the given range
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:short_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:too_short] % range.first</tt>
    # * <tt>:long_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:too_long] % range.last</tt>
    #
    # Example:
    #   it_should_ensure_length_in_range :password, (6..20)
    #
    def it_should_ensure_length_in_range(attribute, range, opts = {})
      short_message, long_message = get_options!([opts], :short_message, :long_message)
      short_message ||= DEFAULT_ERROR_MESSAGES[:too_short] % range.first
      long_message  ||= DEFAULT_ERROR_MESSAGES[:too_long] % range.last

      klass = self.described_type
      min_length = range.first
      max_length = range.last
      same_length = (min_length == max_length)

      if min_length > 0
        describe "allows #{attribute} to be less than #{min_length} chars long" do
          min_value = "x" * (min_length - 1)
          assert_bad_value(klass, attribute, min_value, short_message)
        end
      end

      if min_length > 0
        describe "allows #{attribute} to be exactly #{min_length} chars long" do
          min_value = "x" * min_length
          assert_good_value(klass, attribute, min_value, short_message)
        end
      end

      describe "does not allow #{attribute} to be more than #{max_length} chars long" do
        max_value = "x" * (max_length + 1)
        assert_bad_value(klass, attribute, max_value, long_message)
      end

      unless same_length
        describe "allows #{attribute} to be exactly #{max_length} chars long" do
          max_value = "x" * max_length
          assert_good_value(klass, attribute, max_value, long_message)
        end
      end
    end

    # Ensures that the length of the attribute is at least a certain length
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:short_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:too_short] % min_length</tt>
    #
    # Example:
    #   it_should_ensure_length_at_least :name, 3
    #
    def it_should_ensure_length_at_least(attribute, min_length, opts = {})
      short_message = get_options!([opts], :short_message)
      short_message ||= DEFAULT_ERROR_MESSAGES[:too_short] % min_length

      klass = self.described_type

      if min_length > 0
        min_value = "x" * (min_length - 1)
        describe "does not allow #{attribute} to be less than #{min_length} chars long" do
          assert_bad_value(klass, attribute, min_value, short_message)
        end
      end
      describe "allows #{attribute} to be at least #{min_length} chars long" do
        valid_value = "x" * (min_length)
        assert_good_value(klass, attribute, valid_value, short_message)
      end
    end

    # Ensures that the length of the attribute is exactly a certain length
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:wrong_length] % length</tt>
    #
    # Example:
    #   it_should_ensure_length_is :ssn, 9
    #
    def it_should_ensure_length_is(attribute, length, opts = {})
      message = get_options!([opts], :message)
      message ||= DEFAULT_ERROR_MESSAGES[:wrong_length] % length
      klass = self.described_type

      describe "does not allow #{attribute} to be less than #{length} chars long" do
        min_value = "x" * (length - 1)
        assert_bad_value(klass, attribute, min_value, message)
      end

      describe "does not allow #{attribute} to be greater than #{length} chars long" do
        max_value = "x" * (length + 1)
        assert_bad_value(klass, attribute, max_value, message)
      end

      describe "allows #{attribute} to be #{length} chars long" do
        valid_value = "x" * (length)
        assert_good_value(klass, attribute, valid_value, message)
      end
    end

    # Ensure that the attribute is in the range specified
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:low_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:inclusion]</tt>
    # * <tt>:high_message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:inclusion]</tt>
    #
    # Example:
    #   it_should_ensure_value_in_range :age, (0..100)
    #
    def it_should_ensure_value_in_range(attribute, range, opts = {})
      low_message, high_message = get_options!([opts], :low_message, :high_message)
      low_message  ||= DEFAULT_ERROR_MESSAGES[:inclusion]
      high_message ||= DEFAULT_ERROR_MESSAGES[:inclusion]

      klass = self.described_type
      min   = range.first
      max   = range.last

      describe "does not allow #{attribute} to be less than #{min}" do
        v = min - 1
        assert_bad_value(klass, attribute, v, low_message)
      end

      describe "allows #{attribute} to be #{min}" do
        v = min
        assert_good_value(klass, attribute, v, low_message)
      end

      describe "does not allow #{attribute} to be more than #{max}" do
        v = max + 1
        assert_bad_value(klass, attribute, v, high_message)
      end

      describe "allows #{attribute} to be #{max}" do
        v = max
        assert_good_value(klass, attribute, v, high_message)
      end
    end

    # Ensure that the attribute is numeric
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:not_a_number]</tt>
    #
    # Example:
    #   it_should_only_allow_numeric_values_for :age
    #
    def it_should_only_allow_numeric_values_for(*attributes)
      message = get_options!(attributes, :message)
      message ||= DEFAULT_ERROR_MESSAGES[:not_a_number]
      klass = self.described_type
      attributes.each do |attribute|
        attribute = attribute.to_sym
        describe "only allows numeric values for #{attribute}" do
          assert_bad_value(klass, attribute, "abcd", message)
        end
      end
    end

    # Ensures that the has_many relationship exists.  Will also test that the
    # associated table has the required columns.  Works with polymorphic
    # associations.
    #
    # Options:
    # * <tt>:through</tt> - association name for <tt>has_many :through</tt>
    # * <tt>:dependent</tt> - tests that the association makes use of the dependent option.
    #
    # Example:
    #   it_should_have_many :friends
    #   it_should_have_many :enemies, :through => :friends
    #   it_should_have_many :enemies, :dependent => :destroy
    #
    def it_should_have_many(*associations)
      through, dependent = get_options!(associations, :through, :dependent)
      klass = self.described_type
      associations.each do |association|
        name = "has_many :#{association}"
        name += " :through => #{through}" if through
        name += " :dependent => #{dependent}" if dependent
        describe name do
          reflection = klass.reflect_on_association(association)
          it "should have a relationship" do
            reflection.should_not be_nil
            reflection.macro.should == :has_many
          end

          return if reflection.nil?

          if through
            through_reflection = klass.reflect_on_association(through)
            it "should have relationship to #{through}" do
              through_reflection.should_not be_nil
              through.should == reflection.options[:through]
            end
          end

          if dependent
            it "should have #{association} be dependent on #{dependent}" do
              dependent.to_s.should == reflection.options[:dependent].to_s
            end
          end

          # Check for the existence of the foreign key on the other table
          unless reflection.options[:through]
            if reflection.options[:foreign_key]
              fk = reflection.options[:foreign_key]
            elsif reflection.options[:as]
              fk = reflection.options[:as].to_s.foreign_key
            else
              fk = reflection.primary_key_name
            end

            associated_klass_name = (reflection.options[:class_name] || association.to_s.classify)
            associated_klass = associated_klass_name.constantize

            it "should have #{associated_klass.name} with #{fk} as a foreign key" do
              associated_klass.column_names.should include(fk.to_s)
            end
          end
        end
      end
    end

    # Ensure that the has_one relationship exists.  Will also test that the
    # associated table has the required columns.  Works with polymorphic
    # associations.
    #
    # Options:
    # * <tt>:dependent</tt> - tests that the association makes use of the dependent option.
    #
    # Example:
    #   it_should_have_one :god # unless hindu
    #
    def it_should_have_one(*associations)
      dependent = get_options!(associations, :dependent)
      klass = self.described_type
      associations.each do |association|
        name = "has one #{association}"
        name += " dependent => #{dependent}" if dependent
        reflection = klass.reflect_on_association(association)

        describe name do
          it "should have a relationship" do
            reflection.should_not be_nil
            reflection.macro.should == :has_one
          end

          associated_klass = (reflection.options[:class_name] || association.to_s.camelize).constantize

          if reflection.options[:foreign_key]
            fk = reflection.options[:foreign_key]
          elsif reflection.options[:as]
            fk = reflection.options[:as].to_s.foreign_key
            fk_type = fk.gsub(/_id$/, '_type')
            it "#{associated_klass.name} should have a #{fk_type} column" do
              associated_klass.column_names.should include(fk_type)
            end
          else
            fk = klass.name.foreign_key
          end

          it "should have #{associated_klass.name} have a #{fk} foreign key" do
            associated_klass.column_names.should include(fk.to_s)
          end

          if dependent
            it "should have #{association} be dependent on #{dependent}" do
              reflection.options[:dependent].to_s.should == dependent.to_s
            end
          end
        end
      end
    end

    # Ensures that the has_and_belongs_to_many relationship exists, and that the join
    # table is in place.
    #
    #   it_should_have_and_belong_to_many :posts, :cars
    #
    def it_should_have_and_belong_to_many(*associations)
      get_options!(associations)
      klass = self.described_type

      associations.each do |association|
        reflection = klass.reflect_on_association(association)

        describe "has and belongs to many #{association}" do
          it "should have a relationship" do
            reflection.should_not be_nil
            reflection.macro.should == :has_and_belongs_to_many
          end

          return if reflection.nil?

          table = reflection.options[:join_table]

          it "should have table #{table} exist" do
            ::ActiveRecord::Base.connection.tables.should include(table)
          end
        end
      end
    end

    # Ensure that the belongs_to relationship exists.
    #
    #   it_should_belong_to :parent
    #
    def it_should_belong_to(*associations)
      get_options!(associations)
      klass = self.described_type
      associations.each do |association|
        reflection = klass.reflect_on_association(association)

        describe "belongs to #{association}" do
          it "should have a relationship" do
            reflection.should_not be_nil
            reflection.macro.should == :belongs_to
          end

          unless reflection.options[:polymorphic]
            associated_klass = (reflection.options[:class_name] || association.to_s.camelize).constantize
            fk = reflection.options[:foreign_key] || reflection.primary_key_name
            it "should have a #{fk} foreign key" do
              klass.column_names.should include(fk.to_s)
            end
          end
        end
      end
    end


    # Ensure that the given class methods are defined on the model.
    #
    #   it_should_have_class_methods :find, :destroy
    #
    def it_should_have_class_methods(*methods)
      get_options!(methods)
      klass = self.described_type
      methods.each do |method|
        describe "responds to class method ##{method}" do
          it "should respond" do
            klass.should respond_to(method)
          end
        end
      end
    end

    # Ensure that the given instance methods are defined on the model.
    #
    #   it_should_have_instance_methods :email, :name, :name=
    #
    def it_should_have_instance_methods(*methods)
      get_options!(methods)
      klass = self.described_type
      methods.each do |method|
        describe "responds to instance method ##{method}" do
          it "should respond" do
            klass.new.should respond_to(method)
          end
        end
      end
    end

    # Ensure that the given columns are defined on the models backing SQL table.
    #
    #   it_should_have_db_columns :id, :email, :name, :created_at
    #
    def it_should_have_db_columns(*columns)
      column_type = get_options!(columns, :type)
      klass = self.described_type
      columns.each do |name|
        test_name = "has column #{name}"
        test_name += " of type #{column_type}" if column_type
        describe test_name do
          column = klass.columns.detect {|c| c.name == name.to_s }
          it "should have column" do
            column.should_not be_nil
          end
        end
      end
    end

    # Ensure that the given column is defined on the models backing SQL table.  The options are the same as
    # the instance variables defined on the column definition:  :precision, :limit, :default, :null,
    # :primary, :type, :scale, and :sql_type.
    #
    #   it_should_have_db_column :email, :type => "string", :default => nil,   :precision => nil, :limit    => 255,
    #                                 :null => true,     :primary => false, :scale     => nil, :sql_type => 'varchar(255)'
    #
    def it_should_have_db_column(name, opts = {})
      klass = self.described_type
      test_name = "has column named :#{name}"
      test_name += " with options " + opts.inspect unless opts.empty?
      describe test_name do
        column = klass.columns.detect {|c| c.name == name.to_s }
        it "should have column" do
          column.should_not be_nil
        end

        opts.each do |k, v|
          it "should have :#{name} column on table for #{klass} match option :#{k}" do
            column.instance_variable_get("@#{k}").to_s.should == v.to_s
          end
        end
      end
    end

    # Ensures that there are DB indices on the given columns or tuples of columns.
    # Also aliased to should_have_index for readability
    #
    #   it_should_have_indices :email, :name, [:commentable_type, :commentable_id]
    #   it_should_have_index :age
    #
    def it_should_have_indices(*columns)
      table = self.described_type.name.tableize
      indices = ::ActiveRecord::Base.connection.indexes(table).map(&:columns)

      columns.each do |column|
        describe "has index on #{table} for #{column.inspect}" do
          columns = [column].flatten.map(&:to_s)
          should_contain(indices, columns)
        end
      end
    end

    # Ensures that the model cannot be saved if one of the attributes listed is not accepted.
    #
    # If an instance variable has been created in the setup named after the
    # model being tested, then this method will use that.  Otherwise, it will
    # create a new instance to test against.
    #
    # Options:
    # * <tt>:message</tt> - value the test expects to find in <tt>errors.on(:attribute)</tt>.
    #   Regexp or string.  Default = <tt>I18n.translate('activerecord.errors.messages')[:accepted]</tt>
    #
    # Example:
    #   it_should_require_acceptance_of :eula
    #
    def it_should_require_acceptance_of(*attributes)
      message = get_options!(attributes, :message)
      message ||= DEFAULT_ERROR_MESSAGES[:accepted]
      klass = self.described_type

      attributes.each do |attribute|
        describe "requires #{attribute} to be accepted" do
          assert_bad_value(klass, attribute, false, message)
        end
      end
    end

    # Ensures that the model has a method named scope_name that returns a NamedScope object with the
    # proxy options set to the options you supply.  scope_name can be either a symbol, or a method
    # call which will be evaled against the model.  The eval'd method call has access to all the same
    # instance variables that a should statement would.
    #
    # Options: Any of the options that the named scope would pass on to find.
    #
    # Example:
    #
    #   it_should_have_named_scope :visible, :conditions => {:visible => true}
    #
    # Passes for
    #
    #   named_scope :visible, :conditions => {:visible => true}
    #
    # Or for
    #
    #   def self.visible
    #     scoped(:conditions => {:visible => true})
    #   end
    #
    # You can test lambdas or methods that return ActiveRecord#scoped calls:
    #
    #   it_should_have_named_scope 'recent(5)', :limit => 5
    #   it_should_have_named_scope 'recent(1)', :limit => 1
    #
    # Passes for
    #   named_scope :recent, lambda {|c| {:limit => c}}
    #
    # Or for
    #
    #   def self.recent(c)
    #     scoped(:limit => c)
    #   end
    #
    def it_should_have_named_scope(scope_call, *args)
      klass = self.described_type
      scope_opts = args.extract_options!
      scope_call = scope_call.to_s

      describe scope_call do
        before :each do
          @scope = eval("#{klass}.#{scope_call}")
        end

        describe "return a scope object" do
          it do
            ::ActiveRecord::NamedScope::Scope.should == @scope.class
          end
        end

        unless scope_opts.empty?
          describe "scope itself to #{scope_opts.inspect}" do
            it do
              scope_opts.should == @scope.proxy_options
            end
          end
        end
      end
    end




    private

    # Returns the values for the entries in the args hash who's keys are listed in the wanted array.
    # Will raise if there are keys in the args hash that aren't listed.
    def get_options!(args, *wanted)
      ret  = []
      opts = (args.last.is_a?(Hash) ? args.pop : {})
      wanted.each {|w| ret << opts.delete(w)}
      raise ArgumentError, "Unsupported options given: #{opts.keys.join(', ')}" unless opts.keys.empty?
      return *ret
    end






    ########## assertions
    # Asserts that the given object can be saved
    #
    #  assert_save User.new(params)
    def it_should_save(obj)
      it "should save correctly" do
        if !obj.save
          raise "Errors: #{pretty_error_messages obj}"
        end
        obj.reload
      end
    end

    # Asserts that the given object is valid
    #
    #  assert_valid User.new(params)
    def it_should_be_valid(obj)
      it "should be value" do
        if !obj.valid?
          raise "Errors: #{pretty_error_messages obj}"
        end
      end
    end

    # Asserts that an Active Record model validates with the passed
    # <tt>value</tt> by making sure the <tt>error_message_to_avoid</tt> is not
    # contained within the list of errors for that attribute.
    #
    #   assert_good_value(User.new, :email, "user@example.com")
    #   assert_good_value(User.new, :ssn, "123456789", /length/)
    #
    # If a class is passed as the first argument, a new object will be
    # instantiated before the assertion.  If an instance variable exists with
    # the same name as the class (underscored), that object will be used
    # instead.
    #
    #   assert_good_value(User, :email, "user@example.com")
    #
    #   @product = Product.new(:tangible => false)
    #   assert_good_value(Product, :price, "0")
    def assert_good_value(object_or_klass, attribute, value, error_message_to_avoid = //)
      object = get_instance_of(object_or_klass)
      object.send("#{attribute}=", value)
      object.valid?

      it_should_not_contain(object.errors.on(attribute), error_message_to_avoid, "when set to #{value.inspect}")
    end

    # Asserts that an Active Record model invalidates the passed
    # <tt>value</tt> by making sure the <tt>error_message_to_expect</tt> is
    # contained within the list of errors for that attribute.
    #
    #   assert_bad_value(User.new, :email, "invalid")
    #   assert_bad_value(User.new, :ssn, "123", /length/)
    #
    # If a class is passed as the first argument, a new object will be
    # instantiated before the assertion.  If an instance variable exists with
    # the same name as the class (underscored), that object will be used
    # instead.
    #
    #   assert_bad_value(User, :email, "invalid")
    #
    #   @product = Product.new(:tangible => true)
    #   assert_bad_value(Product, :price, "0")
    def assert_bad_value(object_or_klass, attribute, value,
        error_message_to_expect = DEFAULT_ERROR_MESSAGES[:invalid])
      object = get_instance_of(object_or_klass)
      object.send("#{attribute}=", value)
      object.valid?

      it "should not allow #{value.inspect} as a value for #{attribute}" do
        object.should_not be_valid
      end
      it "should have errors on #{attribute} after being set to #{value.inspect}" do
        object.errors.on(attribute).should_not be_nil
      end

      it_should_contain(object.errors.on(attribute), error_message_to_expect, "when set to #{value.inspect}")
    end

    def pretty_error_messages(obj)
      obj.errors.map { |a, m| "#{a} #{m} (#{obj.send(a).inspect})" }
    end

    private

    def get_instance_of(object_or_klass)
      if object_or_klass.is_a?(Class)
        klass = object_or_klass
        instance_variable_get("@#{klass.to_s.underscore}") || klass.new
      else
        object_or_klass
      end
    end

    ################ core assertions

    # Asserts that the given collection contains item x.  If x is a regular expression, ensure that
    # at least one element from the collection matches x.  +extra_msg+ is appended to the error message if the assertion fails.
    #
    #   assert_contains(['a', '1'], /\d/) => passes
    #   assert_contains(['a', '1'], 'a') => passes
    #   assert_contains(['a', '1'], /not there/) => fails
    def it_should_contain(collection, x, extra_msg = "")
      collection = [collection] unless collection.is_a?(Array)
      msg = "should have error #{x.inspect} #{extra_msg}"
      case x
      when Regexp: 
          it msg do
          collection.should detect { |e| e =~ x }
        end
      else   
        it msg do
          collection.should include(x)
        end
      end
    end

    # Asserts that the given collection does not contain item x.  If x is a regular expression, ensure that
    # none of the elements from the collection match x.
    def it_should_not_contain(collection, x, extra_msg = "")
      collection = [collection] unless collection.is_a?(Array)
      msg = "should not have error #{x.inspect} #{extra_msg}"
      case x
      when Regexp:
          it msg do
          collection.detect { |e| e =~ x }.should be_nil
        end        
      else
        it msg do
          collection.should_not include(x)
        end
      end
    end
    
    
  end

  def self.included(receiver)
    receiver.extend         ExampleGroupMethods
  end
end


# Based off of http://gist.github.com/14050 by http://github.com/awfreeman which in turn was:
# Based off of 
# http://github.com/thoughtbot/shoulda/tree/master/lib/shoulda/active_record/macros.rb 
# and related files

def define_macros
  Spec::Example::ExampleGroupMethods.extend Module.new { yield }
end

DEFAULT_ERROR_MESSAGES =
  if Object.const_defined?(:I18n)
  I18n.translate('activerecord.errors.messages')
else
  ::ActiveRecord::Errors.default_error_messages
end

define_macros do

end