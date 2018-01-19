require "json"
require "logger"
require "habitat"
require "router"

abstract class ActionController::Base
  # Base route => klass name
  CONCRETE_CONTROLLERS = {} of Nil => Nil
  FILTER_TYPES         = %w(ROUTES BEFORE AROUND AFTER RESCUE FORCE)

  {% for ftype in FILTER_TYPES %}
    # klass => {function => options}
    {{ftype.id}}_MAPPINGS = {} of Nil => Nil
  {% end %}

  macro __build_filter_inheritance_macros__
    {% for ftype in FILTER_TYPES %}
      {% ltype = ftype.downcase %}

      macro __inherit_{{ltype.id}}_filters__
        \{% {{ftype.id}}_MAPPINGS[@type.name.id] = LOCAL_{{ftype.id}} %}
        \{% klasses = [@type.name.id] + @type.ancestors %}

        # Create a mapping of all field names and types
        \{% for name in klasses %}
          \{% filters = {{ftype.id}}_MAPPINGS[name.id] %}

          \{% if filters && !filters.empty? %}
            \{% for name, options in filters %}
              \{% if !{{ftype.id}}[name] %}
                \{% {{ftype.id}}[name] = options %}
              \{% end %}
            \{% end %}
          \{% end %}
        \{% end %}
      end
    {% end %}
  end

  CRUD_METHODS = {
    "index"   => {"get", "/"},
    "show"    => {"get", "/:id"},
    "create"  => {"post", "/"},
    "update"  => {"patch", "/:id"},
    "destroy" => {"delete", "/:id"},
  }

  STATUS_CODES = {
    # 1xx informational
    continue:            100,
    switching_protocols: 101,
    processing:          102,

    # 2xx success
    ok:                            200,
    created:                       201,
    accepted:                      202,
    non_authoritative_information: 203,
    no_content:                    204,
    reset_content:                 205,
    partial_content:               206,
    multi_status:                  207,
    already_reported:              208,
    im_used:                       226,

    # 4xx client error
    bad_request:                     400,
    unauthorized:                    401,
    payment_required:                402,
    forbidden:                       403,
    not_found:                       404,
    method_not_allowed:              405,
    not_acceptable:                  406,
    proxy_authentication_required:   407,
    request_timeout:                 408,
    conflict:                        409,
    gone:                            410,
    length_required:                 411,
    precondition_failed:             412,
    payload_too_large:               413,
    uri_too_long:                    414,
    unsupported_media_type:          415,
    range_not_satisfiable:           416,
    expectation_failed:              417,
    misdirected_request:             421,
    unprocessable_entity:            422,
    locked:                          423,
    failed_dependency:               424,
    upgrade_required:                426,
    precondition_required:           428,
    too_many_requests:               429,
    request_header_fields_too_large: 431,
    unavailable_for_legal_reasons:   451,

    # 5xx server error
    internal_server_error:           500,
    not_implemented:                 501,
    bad_gateway:                     502,
    service_unavailable:             503,
    gateway_timeout:                 504,
    http_version_not_supported:      505,
    variant_also_negotiates:         506,
    insufficient_storage:            507,
    loop_detected:                   508,
    not_extended:                    510,
    network_authentication_required: 511,
  }

  REDIRECTION_CODES = {
    # 3xx redirection
    multiple_choices:   300,
    moved_permanently:  301,
    found:              302,
    see_other:          303,
    not_modified:       304,
    use_proxy:          305,
    temporary_redirect: 307,
    permanent_redirect: 308,
  }

  getter render_called
  getter action_name : Symbol
  getter params : Hash(String, String)
  getter cookies : HTTP::Cookies
  getter request : HTTP::Request
  getter response : HTTP::Server::Response

  def initialize(context : HTTP::Server::Context, @params, @action_name)
    @render_called = false
    @request = context.request
    @response = context.response
    @cookies = @request.cookies
  end

  macro render(status = :ok, json = nil, text = nil)
    raise ::ActionController::DoubleRenderError.new if @render_called

    {% if status != :ok || status != 200 %}
      @response.status_code = {{STATUS_CODES[status] || status}}
    {% end %}

    {% if json %}
      @response.content_type = "application/json"
      @response.print({{json}}.to_json)
    {% else %}
      {% if text %}
        @response.content_type = "text/plain"
        @response.print({{text}})
      {% end %}
    {% end %}

    @render_called = true
  end

  macro head(status)
    render({{status}})
  end

  macro redirect_to(path, status = :found)
    raise ::ActionController::DoubleRenderError.new if @render_called

    # TODO:: Support redirect to path name (Symbol)

    @response.status_code = {{REDIRECTION_CODES[status] || status}}
    @response.headers["Location"] = {{path}}
    @render_called = true
  end

  macro inherited
    # default namespace based on class
    NAMESPACE = [{{"/" + @type.name.stringify.underscore.gsub(/\:\:/, "/")}}]

    {% for ftype in FILTER_TYPES %}
      # function => options
      LOCAL_{{ftype.id}} = {} of Nil => Nil
      {{ftype.id}} = {} of Nil => Nil
    {% end %}

    __build_filter_inheritance_macros__

    macro finished
      __build_filter_mappings__
      __create_route_methods__

      # Create draw_routes function
      #
      # Create instance of controller class init with context, params and logger
      # protocol checks (https etc)
      # controller instance created
      # begin exception helpers
      # inline the around filters
      # inline the before filters
      # inline the action
      # inline the after filters
      # rescue exception handlers
      __draw_routes__
    end
  end

  macro __build_filter_mappings__
    {% for ftype in FILTER_TYPES %}
      {% ltype = ftype.downcase %}
      __inherit_{{ltype.id}}_filters__
    {% end %}
  end

  macro __create_route_methods__
    {% if !@type.abstract? %}
      # Add CRUD routes to the map
      {% for name, index in @type.methods.map(&.name.stringify) %}
        {% args = CRUD_METHODS[name] %}
        {% if args %}
          {% ROUTES[name.id] = {args[0], args[1], nil} %}
        {% end %}
      {% end %}

      # Create functions for named routes
      {% for name, details in ROUTES %}
        {% block = details[2] %}
        {% if block != nil %} # Skip the CRUD
          def {{name}}
            {{block.body}}
          end
        {% end %}
      {% end %}

      # Create functions as required for errors
      {% for klass, details in RESCUE %}
        {% block = details[1] %}
        {% if block != nil %} # Skip the CRUD
          def {{details[0]}}({{*details[1].args}})
            {{details[1].body}}
          end
        {% end %}
      {% end %}
    {% end %}
  end

  # To support inheritance
  def self.draw_routes(router)
    nil
  end

  def self.routes
    [] of {Symbol, Symbol, String}
  end

  def self.__yield__(inst)
    with inst yield
  end

  macro __draw_routes__
    {% if !@type.abstract? && !ROUTES.empty? %}
      {% CONCRETE_CONTROLLERS[@type.name.id] = NAMESPACE[0] %}

      def self.draw_routes(router)
        {% for name, details in ROUTES %}
          router.{{details[0].id}} "{{NAMESPACE[0].id}}{{details[1].id}}" do |context, params|

            # Check if force SSL is set and redirect to HTTPS if HTTP
            {% force = false %}
            {% if FORCE[:force] %}
              {% options = FORCE[:force] %}
              {% only = options[0] %}
              {% if only != nil && only.includes?(name) %} # only
                {% force = true %}
              {% else %}
                {% except = options[1] %}
                {% if except != nil && !except.includes?(name) %} # except
                  {% force = true %}
                {% end %}
              {% end %}
            {% end %}
            {% if force %}
              if request_protocol(context.request) != :https
                redirect_to_https(context)
              else
            {% end %}

            # Create an instance of the controller
            instance = {{@type.name}}.new(context, params, :{{name}})

            # Check for errors
            {% if !RESCUE.empty? %}
              begin
            {% end %}

            # Execute the around filters
            {% around_actions = AROUND.keys %}
            {% for method, options in AROUND %}
              {% only = options[0] %}
              {% if only != nil && !only.includes?(name) %} # only
                {% around_actions = around_actions.reject { |act| act == method } %}
              {% else %}
                {% except = options[1] %}
                {% if except != nil && except.includes?(name) %} # except
                  {% around_actions = around_actions.reject { |act| act == method } %}
                {% end %}
              {% end %}
            {% end %}
            {% if !around_actions.empty? %}
              ActionController::Base.__yield__(instance) do
                {% for action in around_actions %}
                    {{action}} do
                {% end %}
            {% end %}

            # Execute the before filters
            {% before_actions = BEFORE.keys %}
            {% for method, options in BEFORE %}
              {% only = options[0] %}
              {% if only != nil && !only.includes?(name) %} # only
                {% before_actions = before_actions.reject { |act| act == method } %}
              {% else %}
                {% except = options[1] %}
                {% if except != nil && except.includes?(name) %} # except
                  {% before_actions = before_actions.reject { |act| act == method } %}
                {% end %}
              {% end %}
            {% end %}
            {% if !before_actions.empty? %}
              {% if around_actions.empty? %}
                ActionController::Base.__yield__(instance) do
              {% end %}
                {% for action in before_actions %}
                  {{action}} unless render_called
                {% end %}
              {% if around_actions.empty? %}
                end
              {% end %}
            {% end %}

            # Check if render could have been before performing the action
            {% if !before_actions.empty? %}
              if !instance.render_called
            {% end %}

              # Call the action
              instance.{{name}}

            {% if !before_actions.empty? %}
              end # END before action render_called check
            {% end %}

            # END around action blocks
            {% if !around_actions.empty? %}
              {% for action in around_actions %}
                nil
                end
              {% end %}
              end
            {% end %}

            # Execute the after filters
            {% after_actions = AFTER.keys %}
            {% for method, options in AFTER %}
              {% only = options[0] %}
              {% if only != nil && !only.includes?(name) %} # only
                {% after_actions = after_actions.reject { |act| act == method } %}
              {% else %}
                {% except = options[1] %}
                {% if except != nil && except.includes?(name) %} # except
                  {% after_actions = after_actions.reject { |act| act == method } %}
                {% end %}
              {% end %}
            {% end %}
            {% if !after_actions.empty? %}
              ActionController::Base.__yield__(instance) do
                {% for action in after_actions %}
                  {{action}}
                {% end %}
              end
            {% end %}

            # Implement error handling
            {% if !RESCUE.empty? %}
              {% for exception, details in RESCUE %}
                rescue e : {{exception.id}}
                  if !instance.render_called
                    instance.{{details[0]}}(e)
                  else
                    raise e
                  end
              {% end %}

              end
            {% end %}

            {% if force %}
              end # END force SSL check
            {% end %}

            # Always return the context
            context
          end
        {% end %}

        nil
      end

      def self.routes
        [
          {% for name, details in ROUTES %}
            {:{{name}}, :{{details[0].id}}, "{{NAMESPACE[0].id}}{{details[1].id}}"},
          {% end %}
        ]
      end
    {% end %}
  end

  macro base(name = nil)
    {% if name.nil? || name.empty? || name == "/" %}
      {% NAMESPACE[0] = "/" %}
    {% else %}
      {% if name.id.stringify.starts_with?("/") %}
        {% NAMESPACE[0] = name.id.stringify %}
      {% else %}
        {% NAMESPACE[0] = "/" + name.id.stringify %}
      {% end %}
    {% end %}
  end

  # Define each method for supported http methods
  {% for http_method in ::Router::HTTP_METHODS %}
    macro {{http_method.id}}(path, name, &block)
      \{% LOCAL_ROUTES[name.id] = { {{http_method}}, path, block } %}
    end
  {% end %}

  macro rescue_from(error_class, method = nil, &block)
    {% if method %}
      {% LOCAL_RESCUE[error_class] = {method.id, nil} %}
    {% else %}
      {% method = error_class.stringify.underscore.gsub(/\:\:/, "_") %}
      {% LOCAL_RESCUE[error_class] = {method.id, block} %}
    {% end %}
  end

  macro around_action(method, only = nil, except = nil)
    {% if only %}
      {% if !only.is_a?(ArrayLiteral) %}
        {% only = [only.id] %}
      {% else %}
        {% only = only.map(&.id) %}
      {% end %}
    {% end %}
    {% if except %}
      {% if !except.is_a?(ArrayLiteral) %}
        {% except = [except.id] %}
      {% else %}
        {% except = except.map(&.id) %}
      {% end %}
    {% end %}
    {% LOCAL_AROUND[method.id] = {only, except} %}
  end

  macro before_action(method, only = nil, except = nil)
    {% if only %}
      {% if !only.is_a?(ArrayLiteral) %}
        {% only = [only.id] %}
      {% else %}
        {% only = only.map(&.id) %}
      {% end %}
    {% end %}
    {% if except %}
      {% if !except.is_a?(ArrayLiteral) %}
        {% except = [except.id] %}
      {% else %}
        {% except = except.map(&.id) %}
      {% end %}
    {% end %}
    {% LOCAL_BEFORE[method.id] = {only, except} %}
  end

  macro after_action(method, only = nil, except = nil)
    {% if only %}
      {% if !only.is_a?(ArrayLiteral) %}
        {% only = [only.id] %}
      {% else %}
        {% only = only.map(&.id) %}
      {% end %}
    {% end %}
    {% if except %}
      {% if !except.is_a?(ArrayLiteral) %}
        {% except = [except.id] %}
      {% else %}
        {% except = except.map(&.id) %}
      {% end %}
    {% end %}
    {% LOCAL_AFTER[method.id] = {only, except} %}
  end

  macro force_ssl(only = nil, except = nil)
    # TODO:: support more options like HSTS headers
    {% if only %}
      {% if !only.is_a?(ArrayLiteral) %}
        {% only = [only.id] %}
      {% else %}
        {% only = only.map(&.id) %}
      {% end %}
    {% end %}
    {% if except %}
      {% if !except.is_a?(ArrayLiteral) %}
        {% except = [except.id] %}
      {% else %}
        {% except = except.map(&.id) %}
      {% end %}
    {% end %}
    {% LOCAL_FORCE[:force] = {only, except} %}
  end

  macro force_tls(only = nil, except = nil)
    force_ssl({{only}}, {{except}})
  end

  macro param(name)
    # extract type and name etc
    # safe_params == hash of extracted params
  end

  def self.request_protocol(request)
    return :https if request.headers["X-Forwarded-Proto"]? =~ /https/i
    return :https if request.headers["Forwarded"]? =~ /https/i
    :http
  end

  def self.redirect_to_https(context)
    req = context.request
    resp = context.response
    resp.status_code = 302
    resp.headers["Location"] = "https://#{req.host}#{req.resource}"
  end

  # ===============
  # Helper methods:
  # ===============
  def format
    ctype = @request.headers["Content-Type"]?
    ctype = ctype.split(";")[0] if ctype
    ctype
  end

  def protocol
    self.class.request_protocol(@request)
  end

  def client_ip
    return @client_ip if @client_ip

    @client_ip = @request.headers["X-Forwarded-Proto"]? || @request.headers["X-Real-IP"]?

    if @client_ip.nil?
      forwarded = @request.headers["Forwarded"]?
      if forwarded
        match = forwarded.match(/for=(.+?)(;|$)/i)
        if match
          ip = match[0]
          ip = ip.split(/=|;/i)[1]
          @client_ip = ip if ip && !["_hidden", "_secret", "unknown"].includes?(ip)
        end
      end

      @client_ip = "127.0.0.1" unless @client_ip
    end

    @client_ip
  end
end
