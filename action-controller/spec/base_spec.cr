require "./spec_helper"

describe ActionController::Base do
  mock_server = MockServer.new(3000)

  spawn do
    mock_server.run
  end

  sleep 0.5

  it "#index" do
    result = curl("GET", "/")
    result.not_nil!.body.should eq("index")
  end

  it "#params" do
    result = curl("GET", "/params/1")
    result.not_nil!.body.should eq("params:1")
    result = curl("GET", "/params/2")
    result.not_nil!.body.should eq("params:2")
  end

  it "#test_param" do
    result = curl("GET", "/params/1/test/3")
    result.not_nil!.body.should eq("{\"id\":\"1\",\"test_id\":\"3\"}")
    result = curl("GET", "/params/2/test/4")
    result.not_nil!.body.should eq("{\"id\":\"2\",\"test_id\":\"4\"}")
  end

  it "#post_test" do
    result = curl("POST", "/post_test/")
    result.not_nil!.body.should eq("ok")
    result.not_nil!.status_code.should eq(202)
  end

  it "#put_test" do
    result = curl("PUT", "/put_test/")
    result.not_nil!.body.should eq("ok")
  end

  it "#unknown_path" do
    result = curl("GET", "/unknown_path")
    result.not_nil!.status_code.should eq(404)
  end

  it "should list routes" do
    Bob.routes.should eq([
      {:show, :get, "/params/:id"},
      {:deep_show, :get, "/params/:id/test/:test_id"},
      {:create, :post, "/post_test"},
      {:update, :put, "/put_test"},
      {:index, :get, "/"},
    ])
  end

  mock_server.close
end
