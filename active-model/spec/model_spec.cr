require "./spec_helper"

# This should not cause compilation errors
class NoAttributes < ActiveModel::Model
end

# Inheritance should be supported
class BaseKlass < NoAttributes
  attribute string : String, "hello"
  attribute integer : Int32, 45
  attribute no_default : String
end

class Inheritance < BaseKlass
  attribute boolean : Bool, true

  macro __customize_orm__
    {% for name, type in FIELDS %}
      def {{name}}_custom
        @{{name}}
      end
    {% end %}
  end
end

describe ActiveModel::Model do
  describe "class definitions" do
    it "should provide the list of attributes" do
      NoAttributes.attributes.should eq [] of Nil
      BaseKlass.attributes.should eq [:string, :integer, :no_default]
      Inheritance.attributes.should eq [:boolean, :string, :integer, :no_default]
    end
  end

  describe "initialization" do
    it "creates a new model with defaults" do
      bk = BaseKlass.new
      bk.attributes.should eq({
        :string     => "hello",
        :integer    => 45,
        :no_default => nil,
      })
    end

    it "creates a new inherited model with defaults" do
      i = Inheritance.new
      i.attributes.should eq({
        :boolean    => true,
        :string     => "hello",
        :integer    => 45,
        :no_default => nil,
      })
    end

    it "creates a new model from JSON" do
      bk = BaseKlass.from_json("{\"boolean\": false, \"integer\": 67}")
      bk.attributes.should eq({
        :string     => "hello",
        :integer    => 67,
        :no_default => nil,
      })

      i = Inheritance.from_json("{\"boolean\": false, \"integer\": 67}")
      i.attributes.should eq({
        :boolean    => false,
        :string     => "hello",
        :integer    => 67,
        :no_default => nil,
      })
    end

    it "uses named params for initialization" do
      bk = BaseKlass.new string: "bob", no_default: "jane"
      bk.attributes.should eq({
        :string     => "bob",
        :integer    => 45,
        :no_default => "jane",
      })

      i = Inheritance.new string: "bob", boolean: false, integer: 2
      i.attributes.should eq({
        :boolean    => false,
        :string     => "bob",
        :integer    => 2,
        :no_default => nil,
      })
    end
  end

  describe "attribute accessors" do
    it "should return attribute values" do
      bk = BaseKlass.new
      bk.string.should eq "hello"
      bk.integer.should eq 45
      bk.no_default.should eq nil

      i = Inheritance.new
      i.boolean.should eq true
      i.string.should eq "hello"
      i.integer.should eq 45
      i.no_default.should eq nil
    end

    it "should allow attribute assignment" do
      bk = BaseKlass.new
      bk.string.should eq "hello"
      bk.string = "what"
      bk.string.should eq "what"

      bk.attributes.should eq({
        :string     => "what",
        :integer    => 45,
        :no_default => nil,
      })

      i = Inheritance.new
      i.boolean.should eq true
      i.boolean = false
      i.boolean.should eq false

      i.attributes.should eq({
        :boolean    => false,
        :string     => "hello",
        :integer    => 45,
        :no_default => nil,
      })
    end
  end

  describe "serialization" do
    it "should support to_json" do
      i = Inheritance.new
      i.to_json.should eq "{\"boolean\":true,\"string\":\"hello\",\"integer\":45}"

      i.no_default = "test"
      i.to_json.should eq "{\"boolean\":true,\"string\":\"hello\",\"integer\":45,\"no_default\":\"test\"}"
    end
  end
end
