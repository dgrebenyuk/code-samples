require 'spec_helper'
require 'parse_utils/log'

describe ParseUtils::Log do
  let(:file_path) { "#{Rails.root}/spec/support/info.log" }
  let(:parser) { ParseUtils::Log.new(file_path) }

  describe '#is_valid?' do
    subject {parser.send(:is_valid?, attrs)}

    context 'when invalid' do
      let(:attrs) { {"level"=>"info", "message"=>"Blacklist Load Success!", "timestamp"=>"2015-05-07T15:25:47.816Z"} }
      it { is_expected.to be_falsey }
    end

    context 'when valid' do
      let(:attrs) { {"type" => "logcall","id" => "CAa7c56b463f1180a03e9be6c25a5ed68e","level" => "info","message" => {"tag" => "Twilio Call Log:","start" => "2015-06-18T13:23:02.000Z","stop" => "2015-06-18T13:23:20.000Z","caller" => "+16617480240","did" => "+19255237412","ctn" => "9253361493","reason" => "twilio callback","type" => "default","status" => "completed","duration" => "18","uri" => "/2010-04-01/Accounts/AC2cb204558bd887c924534d1ff82186c6/Calls/CAa7c56b463f1180a03e9be6c25a5ed68e.json"},"timestamp" => "2015-06-18T13:23:21.820Z"} }
      it { is_expected.to be_truthy }
    end
  end

  describe '#parse_call' do
    subject {parser.send(:parse_call, record)}

    context 'should parse line to json' do
      let(:record) { {"type" => "logcall","id" => "CAa7c56b463f1180a03e9be6c25a5ed68e","level" => "info","message" => "{\"tag\":\"Twilio Call Log:\",\"start\":\"2015-06-18T13:23:02.000Z\",\"stop\":\"2015-06-18T13:23:20.000Z\",\"caller\":\"+16617480240\",\"did\":\"+19255237412\",\"ctn\":\"9253361493\",\"reason\":\"twilio callback\",\"type\":\"default\",\"status\":\"completed\",\"duration\":\"18\",\"uri\":\"/2010-04-01/Accounts/AC2cb204558bd887c924534d1ff82186c6/Calls/CAa7c56b463f1180a03e9be6c25a5ed68e.json\"}","timestamp" => "2015-06-18T13:23:21.820Z"} }
      it { is_expected.to eq({call_id: "CAa7c56b463f1180a03e9be6c25a5ed68e",
        did: "9255237412",
        ctn: "9253361493",
        callers_phone_number: "6617480240",
        duration: 18,
        record_url: "/2010-04-01/Accounts/AC2cb204558bd887c924534d1ff82186c6/Calls/CAa7c56b463f1180a03e9be6c25a5ed68e.json",
        status: "completed",
        date: Time.zone.parse("Thu June 18 2015 06:23:02 GMT-0700 (PDT)"),
        answerby: nil,
        source_type_id: 1
      }) }
    end

  end
end
