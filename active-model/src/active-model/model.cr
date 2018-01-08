require "json"

abstract class ActiveModel::Model
  FIELD_MAPPINGS = {} of Nil => Nil

  macro inherited
    # Macro level constants
    FIELDS = {} of Nil => Nil
    DEFAULTS = {} of Nil => Nil
    HAS_KEYS = [false]

    # Process attributes must be called while constants are in scope
    macro finished
      __process_attributes__
      __customize_orm__
      __map_json__

      # After map JSON as it also creates accessors
      __create_accessors__
    end
  end

  # Prevent compiler errors
  def apply_defaults; end

  macro __process_attributes__
    {% FIELD_MAPPINGS[@type.name.id] = FIELDS %}
    {% klasses = [@type.name] + @type.ancestors %}

    # Generate code to apply default values
    def apply_defaults
      super
      {% for name, data in DEFAULTS %}
        self.{{name}} = {{data}} if self.{{name}}.nil?
      {% end %}
    end

    # Returns a hash of all the attribute values
    def attributes
      {% any = false %}

      {
        {% for name, index in klasses %}
          {% fields = FIELD_MAPPINGS[name.id] %}

          {% if fields && !fields.empty? %}
            {% for name, index in fields.keys %}
              :{{name}} => @{{name}},
              {% any = true %}
            {% end %}
          {% end %}
        {% end %}
      } {% if !any %} of Nil => Nil {% end %}
    end

    # You may want a list of available attributes
    def self.attributes
      {% any = false %}

      [
        {% for name, index in klasses %}
          {% fields = FIELD_MAPPINGS[name.id] %}

          {% if fields && !fields.empty? %}
            {% for name, index in fields.keys %}
              :{{name.id}},
              {% any = true %}
            {% end %}
          {% end %}
        {% end %}
      ] {% if !any %} of Nil {% end %}

      {% HAS_KEYS[0] = any %}
    end
  end

  # For overriding in parent classes
  macro __customize_orm__
  end

  # Adds the from_json method
  macro __map_json__
    {% if HAS_KEYS[0] %}
      {% klasses = [@type.name] + @type.ancestors %}

      JSON.mapping(
        {% for name, index in klasses %}
          {% fields = FIELD_MAPPINGS[name.id] %}

          {% if fields && !fields.empty? %}
              {% for name, type in fields %}
                {{name}}: {{type}} | Nil,
              {% end %}
          {% end %}
        {% end %}
      )

      def initialize(%pull : ::JSON::PullParser)
        previous_def(%pull)
        apply_defaults
      end
    {% end %}
  end

  macro __create_accessors__
    {% klasses = [@type.name] + @type.ancestors %}

    {% for name, index in klasses %}
      {% fields = FIELD_MAPPINGS[name.id] %}

      {% if fields && !fields.empty? %}
          {% for name, type in fields %}
            # Attribute setter
            def {{name}}=(value : {{type}} | Nil)
              @{{name}} = value
            end

            # Attribute getter
            def {{name}}
              @{{name}}
            end
          {% end %}
      {% end %}
    {% end %}

    def initialize(
      {% for name, index in klasses %}
        {% fields = FIELD_MAPPINGS[name.id] %}

        {% if fields && !fields.empty? %}
            {% for name, type in fields %}
              @{{name}} : {{type}} | Nil = nil,
            {% end %}
        {% end %}
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
    {% FIELDS[name.var] = name.type %}
    {% if default %}
      {% DEFAULTS[name.var] = default %}
    {% end %}
  end
end
