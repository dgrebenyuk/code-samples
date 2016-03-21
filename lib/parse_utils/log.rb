require "parse_utils/base"

module ParseUtils
  class Log < Base

    def initialize file_path
      @file_path = file_path
    end

    def perform
      attrs = []
      if File.directory?(@file_path)
        Dir.foreach(@file_path) do |file|
          next if file == '.' or file == '..'

          attrs += load_data_from_file File.join(@file_path, file)
        end
      else
        attrs = load_data_from_file @file_path
      end
      Call.create_or_update_by [:call_id, :status], attrs
    end

    private

    def load_data_from_file file
      attrs = []
      File.readlines(file).each do |line|
        begin
          record = JSON.parse(line)
        rescue Exception => e
          next
        end

        next unless is_valid?(record)

        begin
          attrs << parse_call(record)
        rescue Exception => e

        end
      end if File.exists?(file)
      attrs
    end

    def parse_call record
      message = JSON.parse record['message']
      if message['vendor']
        source_type = SourceType.where(name: message['vendor']).first_or_create
      else
        source_type = SourceType.where(name: 'twilio').first_or_create
      end
      attrs = {
        call_id: record['id'],
        did: prepare_phone(message["did"]),
        ctn: prepare_phone(message["ctn"]),
        callers_phone_number: prepare_phone(message["caller"]),
        duration: parse_int(message["duration"]),
        record_url: message["uri"],
        status: parse_string(message["status"]),
        date: parse_datetime(message["start"]),
        answerby: parse_string(message["answerby"]),
        source_type_id: source_type.id
      }

      # link with partner, offer and business info using the did and ctn
      account = Account.find_by(phone: attrs[:ctn])
      attrs[:account_id] = account.id if account

      if (ob = OffersBusiness.find_by did: attrs[:did])
        attrs[:offer_id] = ob.offer_id
        attrs[:partner_id] = ob.offer.partner_id
        attrs[:business_id] = ob.business_id
      elsif (offer = Offer.find_by ctn: attrs[:ctn])
        attrs[:offer_id] = offer.id
        attrs[:partner_id] = offer.partner_id
      end
      attrs
    end

    def is_valid? record
      message = record['message'].to_s.downcase
      record.has_key?('type') && record['type'].to_s.downcase == 'logcall' && record.has_key?('message') &&
        ( message.include?('twilio') || message.include?('lineup') || message.include?('2600') )
    end

  end
end
