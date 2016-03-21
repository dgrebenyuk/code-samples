require 'spec_helper'

describe HomeController do
  let(:user) { create(:user) }

  describe "#index" do
    it "renders :index if user signed in" do
      sign_in(user)
      get :index
      response.status.should eq(200)
      response.should render_template(:index)
    end

    it "redirects to sign in page if user not signed in" do
      get :index
      response.status.should eq(302)
      response.should redirect_to(new_user_session_path)
    end
  end
end
