module ModelStubbing
  # A Definition holds an array of models with their own stubs.  Also, a definition
  # can set the current time for your tests.  You typically create one per test case or
  # rspec example.
  class Definition
    attr_reader :current_time
    attr_reader :models
    attr_reader :stubs

    # Sets the time that Time.now is mocked to (in UTC)
    def time(*args)
      @current_time = Time.utc(*args)
    end
    
    # Creates a new ModelStubbing::Model to hold one or more stubs.  Multiple calls will append
    # any added stubs to the same model instance.
    def model(klass, options = {}, &block)
      m = Model.new(self, klass, options)
      @models[m.name] ||= m
      @models[m.name].instance_eval(&block) if block
      @models[m.name]
    end
    
    def initialize(&block)
      @models = {}
      @stubs  = {}
      instance_eval &block if block
    end
    
    def dup
      copy = self.class.new
      models.each do |name, model|
        copy.models[name] = model.dup(copy)
      end
      stubs.each do |name, stub|
        copy.stubs[name] = copy.models[stub.model.name].stubs[stub.name]
      end
      copy
    end
    
    def ==(defn)
      (defn.object_id == object_id) ||
        (defn.is_a?(Definition))# && defn.models == @models && defn.stubs == @stubs)
    end
    
    # Sets up the given class for this definition.  Adds a few helper methods:
    #
    # * #stubs: Lets you access all stubs with a global key, which combines the model
    #   name with the stub name.  stubs(:user) gets the default user stub, and stubs(:admin_user)
    #   gets the 'admin' user stub.
    #
    # * #current_time: Accesses the current mocked time for a test or spec.
    #
    # Shortcut methods for each model are generated as well.  users(:default) accesses
    # the default user stub, and users(:admin) accesses the 'admin' user stub.
    def setup_on(klass)
      unless klass.respond_to?(:definition) && klass.definition
        klass.class_eval do
          if klass.is_a?(Class)
            if defined?(Spec::DSL::ExampleGroup) && !klass.ancestors.include?(RspecExtension) && klass.ancestors.include?(Spec::DSL::ExampleGroup)
              include RspecExtension
            elsif defined?(Test::Unit::TestCase) && !klass.ancestors.include?(TestUnitExtension) && klass.ancestors.include?(Test::Unit::TestCase)
              include TestUnitExtension
            end
          end
          def stubs(key, attributes = {})
            self.class.definition.retrieve_record(key, attributes)
          end
          
          def current_time
            self.class.definition.current_time
          end
        end
        (class << klass ; self ; end).send :attr_accessor, :definition
        klass.definition = self
      end
      klass.class_eval models.values.collect { |model| model.stub_method_definition }.join("\n")
    end
    
    # Retrieves a record for a given stub.  The optional attributes hash let's you specify
    # custom attributes.  If no custom attributes are passed, then each call to the same
    # stub will return the same object.  Custom attributes result in a new instantiated object
    # each time.
    def retrieve_record(key, attributes = {})
      @stubs[key].record(attributes)
    end
    
    def database?
      defined?(ActiveRecord)
    end
    
    def inspect
      "(ModelStubbing::Definition(:models => [#{@models.keys.collect { |k| k.to_s }.sort.join(", ")}]))"
    end
  end
end