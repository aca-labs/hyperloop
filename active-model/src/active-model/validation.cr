require "./error"

module ActiveModel::Validation
  property errors = [] of Error

  macro included
    @@validators = Array({field: Symbol, message: String, check: (Proc(self, Bool) | Nil), block: Proc(self, Bool)}).new
  end

  # TODO:: Test this
  macro inherited
    included
  end

  macro validate(field, message, block, positive = nil, negative = nil, **options)
    {% pos = positive || options[:if] %}
    {% neg = negative || options[:unless] %}
    {% if positive || negative %}
      {% if (positive || negative).stringify.starts_with? ":" %}
        {% if positive %}
          @@validators << {field: {{field}}, message: {{message}}, check: ->(this : {{@type.name}}) { !this.{{positive.id}} }, block: {{block}} }
        {% else %}
          @@validators << {field: {{field}}, message: {{message}}, check: ->(this : {{@type.name}}) { !!this.{{negative.id}} }, block: {{block}} }
        {% end %}
      {% else %}
        {% if positive %}
          @@validators << {field: {{field}}, message: {{message}}, check: ->(this : {{@type.name}}) { !{{positive}}.call(this) }, block: {{block}} }
        {% else %}
          @@validators << {field: {{field}}, message: {{message}}, check: ->(this : {{@type.name}}) { !!{{negative}}.call(this) }, block: {{block}} }
        {% end %}
      {% end %}
    {% else %}
      @@validators << {field: {{field}}, message: {{message}}, check: nil, block: {{block}}}
    {% end %}
  end

  macro validate(message, block, **options)
    validate :__base__, {{message}}, {{block}}, {{options[:if]}}, {{options[:unless]}}
  end

  macro __numericality__(fields, num, message, operation, positive, negative)
    {% if num %}
      {% for field, index in fields %}
        validate({{field}}, "{{message.id}} {{num}}", ->(this : {{@type.name}}) {
          number = this.{{field.id}}
          return true unless number.is_a?(Number)
          number {{operation.id}} {{num}}
        }, {{positive}}, {{negative}})
      {% end %}
    {% end %}
  end

  macro validates(*fields,
                  presence = false,
                  numericality = nil,
                  confirmation = nil,
                  **options)
    {% if presence %}
      {% for field, index in fields %}
        validate {{field}}, "is required", ->(this : {{@type.name}}) { !this.{{field.id}}.nil? }, {{options[:if]}}, {{options[:unless]}}
      {% end %}
    {% end %}

    {% if numericality %}
      __numericality__({{fields}}, {{numericality[:greater_than]}}, "must be greater than", ">", {{options[:if]}}, {{options[:unless]}})
      __numericality__({{fields}}, {{numericality[:greater_than_or_equal_to]}}, "must be greater than or equal to", ">=", {{options[:if]}}, {{options[:unless]}})
      __numericality__({{fields}}, {{numericality[:equal_to]}}, "must be equal to", "==", {{options[:if]}}, {{options[:unless]}})
      __numericality__({{fields}}, {{numericality[:less_than]}}, "must be less than", "<", {{options[:if]}}, {{options[:unless]}})
      __numericality__({{fields}}, {{numericality[:less_than_or_equal_to]}}, "must be less than or equal to", "<=", {{options[:if]}}, {{options[:unless]}})
      __numericality__({{fields}}, {{numericality[:other_than]}}, "must be other than", "!=", {{options[:if]}}, {{options[:unless]}})

      {% num = numericality[:odd] %}
      {% if num %}
        {% for field, index in fields %}
          validate {{field}}, "must be odd", ->(this : {{@type.name}}) {
            number = this.{{field.id}}
            return true unless number.is_a?(Number)
            number % 2 == 1
          }, {{options[:if]}}, {{options[:unless]}}
        {% end %}
      {% end %}

      {% num = numericality[:even] %}
      {% if num %}
        {% for field, index in fields %}
          validate {{field}}, "must be even", ->(this : {{@type.name}}) {
            number = this.{{field.id}}
            return true unless number.is_a?(Number)
            number % 2 == 0
          }, {{options[:if]}}, {{options[:unless]}}
        {% end %}
      {% end %}
    {% end %}

    {% if confirmation %}
      {% for field, index in fields %}
        {% type = @type.instance_vars.select { |ivar| ivar.name == field.id }.map(&.type)[0] %}

        # Using attribute for named params support
        attribute {{field.id}}_confirmation : {{FIELDS[field.id]}}

        validate {{field}}, "doesn't match confirmation", ->(this : {{@type.name}}) {
          # Don't error when nil. Use presence to explicitly throw an error here.
          confirmation = this.{{field.id}}_confirmation || this.{{field.id}}
          this.{{field.id}} == confirmation
        }, {{options[:if]}}, {{options[:unless]}}
      {% end %}
    {% end %}
  end

  def valid?
    errors.clear
    @@validators.each do |validator|
      check = validator[:check]
      next if check && check.call(self)
      unless validator[:block].call(self)
        errors << Error.new(self, validator[:field], validator[:message])
      end
    end
    errors.empty?
  end
end
