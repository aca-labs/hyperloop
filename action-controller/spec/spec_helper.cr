require "spec"
require "./curl"
require "../src/action-controller"

class Bob < ActionController::Base
  base "/"

  # Test default CRUD
  def index
    render text: "index"
  end

  get "/params/:id", :show do
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

class MockServer
  include Router

  @server : HTTP::Server?
  @route_handler = RouteHandler.new

  def initialize(@port : Int32)
  end

  def run
    Bob.draw_routes(self)
    @server = HTTP::Server.new(@port, [route_handler]).listen
  end

  def close
    if server = @server
      server.close
    end
  end
end
