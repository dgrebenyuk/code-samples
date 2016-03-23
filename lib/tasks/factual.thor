require 'factual'
require 'sqlite3'

module Import
  class Factual < Thor::Group
    include Thor::Actions

    desc "Enhance import data with factual attributes"
    argument :input_file, type: :string, desc: "Input file in import schema format", required: true
    class_option :path, type: :string, aliases: "-p", desc: "Path to look for input / output file"
    class_option :override_address, type: :boolean, desc: "Override existing address information"
    class_option :override_name, type: :boolean, desc: "Override existing name"

    attr_accessor :database, :factual

    # load active support
    def load_environment
      begin
        Import.load_environment(true)
        say_status :OK, "Loading Environment"
      rescue => e
        say_status :FAIL, "Loading Environment (#{e})", :red
        exit
      end
    end

    def initialize_connections
      self.factual   = ::Factual.new("KEY HERE", "TOKEN HERE")
      self.database  = SQLite3::Database.new(File.join(File.expand_path(options[:path] || 'tmp'), input_file))
    end

    def add_factual_data
      address_fields = <<-SQL
        address_1 = :address_1,
        city = :city,
        state = :state,
        zip_code = :zip_code,
      SQL
      address_fields = "" unless options[:override_address]

      select_stmt = database.prepare(
        <<-SQL
          SELECT 
            licenses.id, licenses.name, licenses.phone_number,
            addresses.id AS address_id, addresses.address_1, addresses.address_2, addresses.city, 
            addresses.state, addresses.zip_code
          FROM addresses
          INNER JOIN licenses ON licenses.id = addresses.addressable_id
          WHERE
            addresses.addressable_type = 'License' AND
            addresses.address_type = 'primary' AND
            (licenses.home_based = 'No' OR licenses.home_based IS NULL) AND
            (licenses.inside_city IS NULL OR licenses.inside_city = 'true') AND
            licenses.factual_checked = 'false' AND
            licenses.factual_resolved = 'false'
        SQL
      )

      update_licenses_stmt = database.prepare(
        <<-SQL
          UPDATE 
            licenses 
          SET 
            name = :name,
            factual_id = :factual_id,
            factual_category_ids = :factual_category_ids,
            factual_chain_id = :factual_chain_id,
            factual_chain_name = :factual_chain_name,
            factual_hours = :factual_hours,
            factual_placerank = :factual_placerank,
            factual_resolved = :factual_resolved,
            factual_checked = 'true'
          WHERE 
            licenses.id = :license_id
        SQL
      )

      update_checked_stmt = database.prepare(
        <<-SQL
          UPDATE 
            licenses 
          SET 
            factual_checked = 'true'
          WHERE 
            licenses.id = :license_id
        SQL
      )

      update_addresses_stmt = database.prepare(
        <<-SQL
          UPDATE 
            addresses 
          SET
            #{address_fields}
            latitude = :latitude,
            longitude = :longitude,
            neighborhood = :neighborhoods
          WHERE 
            addresses.id = :address_id
        SQL
      )

      select_stmt.execute.each_hash do |row|
        row.symbolize_keys!

        query             = { name: row[:name] }
        query[:address]   = row[:address_1] unless row[:address_1].blank?
        query[:locality]  = row[:city] unless row[:city].blank?
        query[:region]    = row[:state] unless row[:state].blank?
        query[:postcode]  = row[:zip_code] unless row[:zip_code].blank?
        query[:tel]       = row[:phone_number] unless row[:phone_number].blank?

        if place = factual.resolve(query, us_only: true).first
          place.symbolize_keys!

          puts "#{row[:id]}: Match found (#{place[:factual_id]})"
          update_licenses_stmt.execute({
            name: options[:override_name] ? place[:name] : row[:name],
            factual_id: place[:factual_id],
            factual_category_ids: place[:category_ids].to_json,
            factual_chain_id: place[:chain_id],
            factual_chain_name: place[:chain_name],
            factual_hours: place[:hours].to_json,
            factual_placerank: place[:placerank],
            factual_resolved: place[:resolved].to_s,
            license_id: row[:id]
          })

          address_params = {
            latitude: place[:latitude],
            longitude: place[:longitude],
            neighborhoods: place[:neighborhood].to_json,
            address_id: row[:address_id]
          }

          address_params.merge!({
            address_1: place[:address],
            city: place[:locality],
            state: place[:region],
            zip_code: place[:postcode]
          }) if options[:override_address]

          update_addresses_stmt.execute(address_params)
        else
          puts "#{row[:id]}: Not Found"
          update_checked_stmt.execute(license_id: row[:id])
        end
      end

      select_stmt.close
      update_licenses_stmt.close
      update_addresses_stmt.close
      update_checked_stmt.close
    end

    def cleanup
      database.close if database
    end
  end
end
