require "json"
require "logger"
require "habitat"
require "router"

class ActionController::WebServer
  include Router
end

class ActionController::Base
  # klass => {function, options}
  BEFORE = {} of Nil => Nil
  AROUND = {} of Nil => Nil
  AFTER  = {} of Nil => Nil
  RESCUE = {} of Nil => Nil

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

    # 3xx redirection
    multiple_choices:   300,
    moved_permanently:  301,
    found:              302,
    see_other:          303,
    not_modified:       304,
    use_proxy:          305,
    temporary_redirect: 307,
    permanent_redirect: 308,

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

  # def self.yield_controller(instance)
  #  with instance yield
  # end

  getter render_called
  getter params : Hash(String, String)
  getter cookies : HTTP::Cookies
  getter request : HTTP::Request
  getter response : HTTP::Server::Response

  def initialize(context : HTTP::Server::Context, @params)
    @render_called = false
    @request = context.request
    @response = context.response
    @cookies = @request.cookies
  end

  macro render(head = :ok, json = nil, text = nil)
    {% if head != :ok || head != 200 %}
      @response.status_code = {{STATUS_CODES[head] || head}}
    {% end %}

    {% if json %}
      @response.print({{json}}.to_json)
    {% else %}
      {% if text %}
        @response.print({{text}})
      {% end %}
    {% end %}

    @render_called = true
  end

  macro inherited
    # default namespace based on class
    # defines CRUD operations if functions are defined
    NAMESPACE = [@type.name.stringify.underscore.gsub("::", "/")]
    LOCAL_BEFORE = {} of Nil => Nil
    ROUTES = {} of Nil => Nil # {type, route} => block

    macro finished
      __detect_crud__
      __draw_routes__
      # Create draw_routes function
      # -> Create get / post requests (as per router.cr)
      #
      # Create instance of controller class init with context, params and logger
      # inline the before actions
      # inline the around actions
      # inline the block code or function call (when CRUD)
      # inline the after actions
      # inline rescue code
      #
      # After each step check if render has been called and return if it has

      # Add draw_routes proc to a Server class used to define the HTTP::Server and route handlers
      # Add route paths to the Server class for printing (app --show-routes)
    end
  end

  macro __detect_crud__
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
  end

  # To support inheritance
  def self.draw_routes(router)
    nil
  end

  def self.routes
    [] of {Symbol, Symbol, String}
  end

  macro __draw_routes__
    def self.draw_routes(router)
      # Draw the inherited routes
      super(router)

      {% for name, details in ROUTES %}
        router.{{details[0].id}} "{{NAMESPACE[0].id}}{{details[1].id}}" do |context, params|
          # Check if force SSL is set and redirect to HTTPS if HTTP

          # Create an instance of the controller
          instance = {{@type.name}}.new(context, params)

          # Execute the before actions
          # Check if instance called after each action
          if !instance.render_called
            # Call the action
            instance.{{name}}

            # Execute the after actions

          end

          # Always return the context
          context
        end
      {% end %}

      nil
    end

    def self.routes
      super + [
        {% for name, details in ROUTES %}
          {:{{name}}, :{{details[0].id}}, "{{NAMESPACE[0].id}}{{details[1].id}}"},
        {% end %}
      ]
    end
  end

  macro base(name = nil)
    {% if name.nil? || name.empty? || name == "/" %}
      {% NAMESPACE[0] = "" %}
    {% else %}
      {% NAMESPACE[0] = "/" + name.id.stringify %}
    {% end %}
  end

  # Define each method for supported http methods
  {% for http_method in ::Router::HTTP_METHODS %}
    macro {{http_method.id}}(path, name, &block)
      \{% ROUTES[name.id] = { {{http_method}}, path, block } %}
    end
  {% end %}

  macro rescue_from(error_class, method = nil, &block)

  end

  macro around_action(method, **options)

  end

  macro before_action(method, **options)

  end

  macro after_action(method, **options)

  end

  macro force_ssl(**options)
    # only, except etc
  end

  macro param(name)
    # extract type and name etc
    # safe_params == hash of extracted params
  end
end
