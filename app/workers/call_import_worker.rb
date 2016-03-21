class CallImporterWorker
  require 'parse_utils/log'

  include Sidekiq::Worker

  sidekiq_options queue: :high, retry: false

  def perform
    ParseUtils::Log.new(Settings.call_log_dir).perform
  end

end
