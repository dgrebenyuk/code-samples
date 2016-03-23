module Export
  class Create < Thor::Group
    include Thor::Actions

    attr_accessor :license_template, :schema 

    desc "Export city data"
    argument :template_id, type: :numeric, desc: "License Template Id"
    argument :output_file, type: :string, desc: "Sqlite3 output file", optional: true
    class_option :path, type: :string, aliases: "-p", desc: "Path to find input file"

    # load rails
    def load_environment
      begin
        require File.expand_path('config/environment.rb')
        say_status :OK, "Loading Environment"
      rescue
        say_status :FAIL, "Loading Environment", :red
        exit
      end
    end

    def setup
      require 'import/schema'
      self.schema           = ::Export::Schema.new(File.join(File.expand_path(options[:path] || 'tmp'), output_file))
      self.license_template = LicenseTemplate.where(id: template_id).includes(:government).first
      self.schema.reset(true)
    end

    def export_categories
      license_template.license_categories.find_in_batches do |categories|
        schema.bulk_insert(:categories, categories.collect {|c| {
          id:         c.id,
          name:       c.name,
          created_at: format_date(c.created_at),
          updated_at: format_date(c.updated_at)
        }})
      end

      say_status :OK, "Loading Categories"
    end

    def export_licenses
      license_template.licenses.includes(licensee: [:owners, :contacts]).find_in_batches do |licenses|
        schema.bulk_insert(:licenses, licenses.collect {|l| {
          id:                   l.id,
          legacy_id:            l.gov_acct_no,
          category_id:          l.license_category_id,
          naics_category_id:    l.naics_category_id,
          name:                 l.name,
          phone_number:         l.licensee.try(:phone),
          phone_number_2:       l.licensee.try(:public_phone),
          fax_number:           l.licensee.try(:fax),
          home_based:           format_boolean(l.licensee.try(:home_based)),
          inside_city:          format_boolean(l.licensee.try(:inside_city)),
          owners:               l.licensee.try(:owners).try(:count),
          start_date:           format_date(l.licensee.try(:start_date)),
          closed_date:          format_date(l.licensee.try(:close_date)),
          created_at:           format_date(l.created_at),
          updated_at:           format_date(l.updated_at)
        }})
      end

      say_status :OK, "Loading Licenses"
    end

    def export_snapshots
      license_template.license_snapshots.find_in_batches do |snapshots|
        schema.bulk_insert(:snapshots, snapshots.collect {|s| {
          id:               s.id,
          legacy_id:        s.legacy_id,
          license_id:       s.license_id,
          issue_date:       format_date(s.issue_date),
          expiration_date:  format_date(s.expiration_date),
          status:           s.snapshot_status,
          process_as:       s.process_as,
          created_at:       format_date(s.created_at),
          updated_at:       format_date(s.updated_at)
        }})
      end

      say_status :OK, "Loading Snapshots"
    end

    def export_notes
      LicenseNote.joins(:license).where("licenses.license_template_id = ?", license_template.id)
        .find_in_batches do |notes|

        schema.bulk_insert(:notes, notes.collect {|n| {
          id:                   n.id,
          legacy_id:            n.legacy_id,
          license_id:           n.license_id,
          note:                 n.note,
          internal:             format_boolean(n.internal),
          user_name:            n.username,
          created_at:           format_date(n.created_at),
          updated_at:           format_date(n.updated_at)
        }})
      end

      say_status :OK, "Loading Notes"
    end

    def export_fees
      LicenseFee.joins(:license).where("licenses.license_template_id = ?", license_template.id)
        .find_in_batches do |fees|

        schema.bulk_insert(:fees, fees.collect {|f| {
          id:                   f.id,
          legacy_id:            f.legacy_id,
          license_id:           f.license_id,
          snapshot_id:          f.license_snapshot_id,
          name:                 f.name,
          description:          f.description,
          amount:               f.amount.to_f,
          amount_paid:          f.paid_amount.to_f,
          adjustments:          f.adjustments.to_f,
          created_at:           format_date(f.created_at),
          updated_at:           format_date(f.updated_at)
        }})
      end

      say_status :OK, "Loading Fees"
    end

    def export_payments
      LicenseReceipt.joins(:license).includes(:payment_type)
        .where("licenses.license_template_id = ?", license_template.id)
        .find_in_batches do |payments|

        schema.bulk_insert(:payments, payments.collect {|p| {
          id:                   p.id,
          legacy_id:            p.legacy_id,
          license_id:           p.license_id,
          description:          p.name,
          amount:               p.amount.to_f,
          user_name:            p.employee,
          payment_type:         p.payment_type.try(:name),
          payment_type_number:  p.check_number.presence || p.card_last_4_digits.presence,
          payment_type_details: p.account_details,
          created_at:           format_date(p.created_at),
          updated_at:           format_date(p.updated_at)
        }})
      end

      say_status :OK, "Loading Payments"
    end

    def export_adjustments
      LicenseFeeAdjustment.joins(:license)
        .where("licenses.license_template_id = ?", license_template.id)
        .find_in_batches do |adjustments|

        schema.bulk_insert(:adjustments, adjustments.collect {|a| {
          id:                   a.id,
          legacy_id:            a.legacy_id,
          license_id:           a.license_id,
          fee_id:               a.license_fee_id,
          amount:               a.amount.to_f,
          description:          a.notes,
          user_name:            a.username,
          created_at:           format_date(a.created_at),
          updated_at:           format_date(a.updated_at)
        }})
      end

      say_status :OK, "Loading Adjustments"
    end

    def export_answers
      LicenseAnswer.joins(license: [], license_template_item:  [:license_template_group, :license_question])
        .where("licenses.license_template_id = ?", license_template.id)
        .find_in_batches do |answers|

        schema.bulk_insert(:answers, answers.collect {|a| {
          id:           a.id,
          legacy_id:    a.legacy_id,
          license_id:   a.license_id,
          name:         a.license_template_item.try(:export_name),
          value:        a.value,
          created_at:   format_date(a.created_at),
          updated_at:   format_date(a.updated_at)
        }})
      end

      say_status :OK, "Loading Answers"
    end

    private
      def format_date(date)
        return unless date.respond_to?(:strftime)
        date.strftime("%Y-%m-%d %H:%M:%S")
      end

      def format_boolean(boolean)
        case boolean
        when true, 'Yes','y','t' then 't'
        when false,'No','n','f' then 'f'
        else
          nil
        end
      end

      def strip_whitespace(string)
        return nil unless string
        string.gsub!(/\s+/, ' ')
      end
  end
end
