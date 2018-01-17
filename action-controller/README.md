# Hyperloop Action Controller

Extending [router.cr](https://github.com/tbrand/router.cr) for a Rails like DSL without the overhead.


## Usage

Supports many of the helpers that Rails provides for controllers. i.e. before and after filters

```crystal
require "action-controller"

abstract class Application < ActionController::Base
  before_action :ensure_authenticated

  rescue_from DivisionByZero do |error|
    render :bad_request, text: error.message
  end

  private def ensure_authenticated
    render :unauthorized unless cookies["user"]
  end
end

class Books < Application
  base "/books" # <= this is automatically

  def index
    render json: ["book1", "book2"]
  end

  def show
    render text: params["id"]
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

  def index
    raise ::ActionController::DoubleRenderError.new if @render_called
    @response.content_type = "text/plain"
    @response.print("index")
    @render_called = true
  end

  def show
    raise ::ActionController::DoubleRenderError.new if @render_called
    @response.content_type = "application/json"
    @response.print({id: params["id"]}.to_json)
    @render_called = true
  end

  def route_name
    raise ::ActionController::DoubleRenderError.new if @render_called
    @response.status_code = 202
    @response.content_type = "text/plain"
    @response.print("simple right?")
    @render_called = true
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
