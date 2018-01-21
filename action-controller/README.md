# Hyperloop Action Controller

Extending [router.cr](https://github.com/tbrand/router.cr) for a Rails like DSL without the overhead.


## Usage

Supports many of the helpers that Rails provides for controllers. i.e. before and after filters

```crystal
require "action-controller"

# Abstract classes don't generate routes
abstract class Application < ActionController::Base
  before_action :ensure_authenticated

  rescue_from DivisionByZero do |error|
    render :bad_request, text: error.message
  end

  private def ensure_authenticated
    render :unauthorized unless cookies["user"]
  end
end

# Full inheritance support (concrete classes generate routes)
class Books < Application
  # this is automatically configured based on class name and namespace
  # it can be overriden here
  base "/books"

  def index
    render json: ["book1", "book2"]
  end

  def show
    respond_with do
      text "the ID was #{params["id"]}"
      json({id: params["id"]})
      xml do
        XML.build(indent: "  ") do |xml|
          xml.element("id") { xml.text params["id"] }
        end
      end
    end
  end
end
```


### Code Expansion

```crystal
require "action-controller"

class MyResource < ActionController::Base
  base "/resource"

  def index
    render text: "index"
  end

  def show
    render json: {id: params["id"]}
  end

  put "/custom/route", :route_name do
    render :accepted, text: "simple right?"
  end
end
```

Results in the following high performance code being generated:

```crystal
class MyResource < ActionController::Base
  getter logger : Logger
  getter render_called
  getter action_name : Symbol
  getter params : HTTP::Params
  getter cookies : HTTP::Cookies
  getter request : HTTP::Request
  getter response : HTTP::Server::Response

  def initialize(context : HTTP::Server::Context, params : Hash(String, String), @action_name)
    @render_called = false
    @request = context.request
    @response = context.response
    @cookies = @request.cookies
    @params = @request.query_params

    @logger = settings.logger

    # Add route params to the HTTP params
    # giving preference to route params
    params.each do |key, value|
      values = @params.fetch_all(key) || [] of String
      values.unshift(value)
      @params.set_all(key, values)
    end
  end

  def index
    raise ::ActionController::DoubleRenderError.new if @render_called
    @render_called = true
    ctype = @response.headers["Content-Type"]?
    @response.content_type = "text/plain" unless ctype
    @response.print("index")
  end

  def show
    raise ::ActionController::DoubleRenderError.new if @render_called
    @render_called = true
    ctype = @response.headers["Content-Type"]?
    @response.content_type = "application/json" unless ctype
    output = {id: params["id"]}
    if output.is_a?(String)
      @response.print(output)
    else
      @response.print(output.to_json)
    end
  end

  def route_name
    raise ::ActionController::DoubleRenderError.new if @render_called
    @render_called = true
    @response.status_code = 202
    ctype = @response.headers["Content-Type"]?
    @response.content_type = "text/plain" unless ctype
    @response.print("simple right?")
  end

  def self.draw_routes(router)
    # Supports inheritance
    super(router)

    # Implement the router.cr compatible routes:
    router.get "/resource/" do |context, params|
      instance = MyResource.new(context, params)
      instance.index
      context
    end

    router.get "/resource/:id" do |context, params|
      instance = MyResource.new(context, params)
      instance.show
      context
    end

    router.put "/resource/custom/route" do |context, params|
      instance = MyResource.new(context, params)
      instance.route_name
      context
    end
  end
end
```
