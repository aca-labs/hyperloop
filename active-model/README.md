# Hyperloop ActiveModel

Active Model provides a known set of interfaces for usage in model classes. Active Model also helps with building custom ORMs.


## Usage

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
