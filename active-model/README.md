# Hyperloop ActiveModel

Active Model provides a known set of interfaces for usage in model classes. Active Model also helps with building custom ORMs.


## Usage

### Active Model

ActiveModel::Model should be used as the base class for your ORM

```crystal
require "active-model"

class Person < ActiveModel::Model
  attribute name : String, "default value"
  attribute age : Int32
end

p = Person.from_json("\"name\": \"Bob Jane\"")
p.name # => "Bob Jane"
p.to_json # => "\"name\":\"Bob Jane\""
p.attributes # => {:name => "Bob Jane", :age => nil}

p.age = 32
p.attributes # => {:name => "Bob Jane", :age => 32}
```

The `attribute` macro takes two parameters. The field name with type and an optional default value.


#### Validations

ActiveModel::Validators is a mix-in that you include in your class:

```crystal
require "active-model/validation"

class Person
  include ActiveModel::Validation
  property name : String?
  
  validate :name, "is required", -> (this : Person) { this.name != nil }
  
  validate :name, "must be 3 characters long", -> (this : Person) do 
    if name = this.name
      return name.size > 2
    end
    return true
  end
  
  def initialize(@name = nil)
  end
end
```

The `validate` macro takes three parameters.  The symbol of the field and the message that will
display when the validation fails.  The third is a `Proc` that is provided an
instance of `self` and returns either true or false.

To check to see if your instance is valid, call `valid?`.  Each Proc will be
called and if any of them fails, an `errors` Array with the messages is
returned.

If no Symbol is provided as a first parameter, the errors will be added to the `:base` field.

```crystal
person = Person.new(name: "JD")
person.valid?.should eq false
person.errors[0].to_s.should eq "Name must be 3 characters long"
```

