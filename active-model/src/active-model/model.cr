require "json"

abstract class ActiveModel::Model
  FIELD_MAPPINGS = {} of Nil => Nil

  macro inherited
    # Macro level constants
    LOCAL_FIELDS = {} of Nil => Nil
    DEFAULTS = {} of Nil => Nil
    HAS_KEYS = [false]
    FIELDS = {} of Nil => Nil


    # Process attributes must be called while constants are in scope
    macro finished
      __process_attributes__
      __customize_orm__
      __map_json__ # This creates the accessors
      __create_initializer__
    end
  end

  # Prevent compiler errors
  def apply_defaults; end

  macro __process_attributes__
    {% FIELD_MAPPINGS[@type.name.id] = LOCAL_FIELDS %}
    {% klasses = @type.ancestors %}

    # Create a mapping of all field names and types
    {% for name, index in klasses %}
      {% fields = FIELD_MAPPINGS[name.id] %}

      {% if fields && !fields.empty? %}
        {% for name, type in fields %}
          {% FIELDS[name] = type %}
          {% HAS_KEYS[0] = true %}
        {% end %}
      {% end %}
    {% end %}

    # Generate code to apply default values
    def apply_defaults
      super
      {% for name, data in DEFAULTS %}
        self.{{name}} = {{data}} if self.{{name}}.nil?
      {% end %}
    end

    # Returns a hash of all the attribute values
    def attributes
      {
        {% for name, index in FIELDS.keys %}
          :{{name}} => @{{name}},
        {% end %}
      } {% if !HAS_KEYS[0] %} of Nil => Nil {% end %}
    end

    # You may want a list of available attributes
    def self.attributes
      [
        {% for name, index in FIELDS.keys %}
          :{{name.id}},
        {% end %}
      ] {% if !HAS_KEYS[0] %} of Nil {% end %}
    end
  end

  # For overriding in parent classes
  macro __customize_orm__
  end

  # Adds the from_json method
  macro __map_json__
    {% if HAS_KEYS[0] %}
      JSON.mapping(
        {% for name, type in FIELDS %}
          {{name}}: {{type}} | Nil,
        {% end %}
      )

      def initialize(%pull : ::JSON::PullParser)
        previous_def(%pull)
        apply_defaults
      end
    {% end %}
  end

  macro __create_initializer__
    def initialize(
      {% for name, type in FIELDS %}
        @{{name}} : {{type}} | Nil = nil,
      {% end %}
    )
      apply_defaults
    end
  end

  macro attribute(name, default = nil)
    # Attribute default value
    def {{name.var}}_default : {{name.type}} | Nil
      {{default}}
    end

    # Save field details for finished macro
    {% LOCAL_FIELDS[name.var] = name.type %}
    {% FIELDS[name.var] = name.type %}
    {% HAS_KEYS[0] = true %}
    {% if default %}
      {% DEFAULTS[name.var] = default %}
    {% end %}
  end
end
