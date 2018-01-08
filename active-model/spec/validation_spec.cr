require "./spec_helper"

class Person < ActiveModel::Model
  include ActiveModel::Validation

  attribute name : String
  attribute age : Int32, 32
  attribute gender : String

  validate :name, "is required", ->(this : Person) { !this.name.nil? }
  validate :name, "must be 3 characters long", ->(this : Person) do
    if name = this.name
      return name.size > 2
    end
    return true
  end

  validates :age, presence: true
  validates :age, numericality: {:greater_than => 5}

  validates :gender, confirmation: true

  validate("too old", ->(this : Person) {
    this.gender == "female"
  }, if: :age_test)

  def age_test
    age = self.age
    age && age > 80
  end
end

describe ActiveModel::Validation do
  describe "presence" do
    it "validates presence of name" do
      person = Person.new(name: "John Doe")
      person.valid?.should eq true
    end

    it "returns false if name is not present" do
      person = Person.new
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Name is required"
    end

    it "returns false if age is not present" do
      person = Person.new name: "bob"
      person.age = nil
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Age is required"
    end
  end

  describe "numericality" do
    it "returns false if age is not greater than 5" do
      person = Person.new name: "bob", age: 5
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Age must be greater than 5"
    end
  end

  describe "confirmation" do
    it "should create and compare confirmation field" do
      person = Person.new name: "bob", gender: "female", gender_confirmation: "male"
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Gender doesn't match confirmation"

      # A nil version of the confirmation is ignored
      person = Person.new name: "bob", gender: "female"
      person.valid?.should eq true
    end
  end

  describe "if/unless check" do
    it "should check gender if the age is great" do
      person = Person.new name: "bob", gender: "female", age: 81
      person.valid?.should eq true

      person.age = 70
      person.gender = "male"
      person.valid?.should eq true

      person.age = 81
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Person too old"
    end
  end

  describe "validate length" do
    it "returns valid if name is greater than 2 characters" do
      person = Person.new(name: "John Doe")
      person.valid?.should eq true
    end

    it "returns invalid if name is less than 2 characters" do
      person = Person.new(name: "JD")
      person.valid?.should eq false
      person.errors[0].to_s.should eq "Name must be 3 characters long"
    end
  end
end
