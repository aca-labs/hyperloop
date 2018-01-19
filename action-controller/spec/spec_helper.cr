require "spec"
require "./curl"
require "../src/action-controller"

class BobJane < ActionController::Base
  # base "/bob/jane" # <== automatically configured

  # Test default CRUD
  def index
    render text: "index"
  end

  get "/redirect", :redirect do
    redirect_to "/other_route"
  end

  get "/params/:id", :param_id do
    render text: "params:#{params["id"]}"
  end

  get "/params/:id/test/:test_id", :deep_show do
    render json: {
      id:      params["id"],
      test_id: params["test_id"],
    }
  end

  post "/post_test", :create do
    render :accepted, text: "ok"
  end

  put "/put_test", :update do
    render text: "ok"
  end
end

abstract class Application < ActionController::Base
  rescue_from DivisionByZero do |error|
    render :bad_request, text: error.message
  end
end

class HelloWorld < Application
  base "/hello"

  force_tls only: [:destroy]

  around_action :around1, only: :around
  around_action :around2, only: :around

  before_action :set_var, except: :show
  after_action :after, only: :show

  def show
    raise "set_var was set!" if @me
    res = 42 / params["id"].to_i
    render text: "42 / #{params["id"]} = #{res}"
  end

  def index
    render text: "set_var #{@me}"
  end

  get "/around", :around do
    render text: "var is #{@me}"
  end

  def update
    render :accepted, text: "Thanks!"
    redirect_to "/"
  end

  def destroy
    head :accepted
  end

  private def set_var
    me = @me
    me ||= 0
    me += 123
    @me = me
  end

  private def after
    puts "after #{action_name}"
  end

  private def around1
    @me = 7
    yield
  end

  private def around2
    me = @me
    me ||= 0
    me += 3
    @me = me
    yield
  end
end

class MockServer
  include Router

  @server : HTTP::Server?
  @route_handler = RouteHandler.new

  def initialize(@port : Int32)
  end

  def run
    {% for klass in ActionController::Base::CONCRETE_CONTROLLERS %}
      {{klass}}.draw_routes(self)
    {% end %}
    @server = HTTP::Server.new(@port, [route_handler]).listen
  end

  def close
    if server = @server
      server.close
    end
  end
end
