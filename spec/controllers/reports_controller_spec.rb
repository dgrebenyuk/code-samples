require 'spec_helper'

describe ReportsController do
  let(:user) { create(:user) }

  describe '#call_traffic_data_range' do
    it "returns 'unauthorized' status if user not signed in" do
      post :call_traffic_data_range, format: :js
      expect(response.status).to eq(401)
    end

    it "redirects to root_path if user has no rights" do
      sign_in(user)
      post :call_traffic_data_range, format: :js
      expect(response.status).to eq(302)
      expect(response).to redirect_to(root_path)
    end

    context 'when user is signed in and have rights' do
      let!(:call_1) { create(:call, date: '2015-05-14', duration: 50) }
      let!(:call_2) { create(:call, date: '2015-05-10') }

      before :each do
        user.add_role(:admin)
        sign_in(user)
      end


      xit 'returns calls traffic stats of selected date range' do
        post :call_traffic_data_range, format: :js, date_range: { start_date: '2015-05-11', end_date: '2015-05-14' }
        expect(response.content_type).to eq('application/json')
        expect(response.status).to eq(200)
        expect(json_response).to eq({
                                    "traffic_stats_date_range_total_calls_10_seconds_or_less"=>0,
                                    "traffic_stats_date_range_total_minutes_consumed"=>0.83,
                                    "traffic_stats_date_range_blacklisted_calls"=>0,
                                    "traffic_stats_date_range_agency_calls"=>"",
                                    "traffic_stats_date_range_average_duration"=>50
                                    })
      end
      after(:each) { Call.delete_all }
    end
  end

  describe '#export_calls_traffic' do
    it "redirects to sign in page if user not signed in" do
      post :export_calls_traffic
      expect(response.status).to eq(302)
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'redirects to root_path if user has no rights' do
      sign_in(user)
      post :export_calls_traffic
      expect(response.status).to eq(302)
      expect(response).to redirect_to(root_path)
    end

    context 'when user is signed in and have rights' do
      let!(:call_1) { create(:call, date: '2015-05-14', duration: 50) }

      before :each do
        user.add_role(:admin)
        sign_in(user)
      end

      it 'creates calls traffic report' do
        allow_any_instance_of(Axlsx::Package).to receive(:serialize)
        allow(controller).to receive(:render)
        expect(controller).to receive(:send_file)
        post :export_calls_traffic, export: { start_date: '2015-05-11', end_date: '2015-05-14' }
      end

      after(:each) { Call.delete_all }
    end
  end

end
