require 'spec_helper'

describe HomeController, type: :controller do

  describe "GET 'index'" do

    before(:each) do
      get 'index'
    end

    it "returns success" do
      expect(response).to be_success
    end

    it "returns the expected json header" do
      expect(response.content_type).to eq("application/json")
    end

    it "should respond with a json response for the root" do
      json_response = JSON.parse(response.body)
      expect(json_response).to eq({})
    end
  end
end
