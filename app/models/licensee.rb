class Licensee < ActiveRecord::Base
  # Constants for length validation
  MAX_TAGLINE_LENGTH = 150
  MAX_DESCRIPTION_LENGTH = 10_000
  MAX_DIRECTORY_NAME_LENGTH = 100
  PHONE_LENGTH = 10
  NEWSFEED_PER_PAGE = 10
  MAX_STANDART_IMAGES = 10
  MAX_HEADER_IMAGES = 10

  ################################
  # Associations
  ################################
  belongs_to :naics_category
  belongs_to :government, :counter_cache => true
  belongs_to :type, :class_name => "LicenseeType", :foreign_key => "licensee_type_id"
  belongs_to :assigned_user, :class_name => "User", :foreign_key => "assigned_to"
  has_many :licensee_leads
  has_many :licensee_contracts, :dependent => :destroy
  has_one :current_contract, -> { order("end_date DESC, created_at DESC") }, class_name: 'LicenseeContract'
  has_many :licensee_e2g2_categories, :dependent => :destroy
  has_many :licensee_languages, :dependent => :destroy
  has_many :licensee_offers, :dependent => :destroy
  has_many :user_redeemed_offers, through: :licensee_offers
  has_many :current_licensee_offers, -> { where "licensee_offers.draft = false AND closed = false AND active = true AND (NOW() BETWEEN licensee_offers.start_date AND licensee_offers.end_date +  INTERVAL '1 DAY')" }, :dependent => :destroy, :class_name => "LicenseeOffer"
  has_many :licensee_payment_methods, :dependent => :destroy
  has_many :licensee_reviews, :dependent => :destroy
  has_many :licensee_review_invitations, :dependent => :destroy
  has_many :licenses
  has_one :defining_license, -> { order "id DESC" }, class_name: 'License'
  has_many :license_categories, :through => :licenses
  has_many :e2g2_categories, -> { order 'rank ASC, e2g2_categories.full_name ASC' }, :through => :licensee_e2g2_categories
  has_many :payment_methods, :through => :licensee_payment_methods
  has_many :active_licenses, -> { where :status => "active" }, :class_name => "License"
  has_many :comments, :as => :commentable, :dependent => :destroy
  has_many :contacts, -> { where :current => true }, :as => :contactable, :dependent => :destroy
  has_one :current_owner_contact, -> { where :current => true }, :class_name => 'Contact', :as => :contactable
  has_many :associations, :as => :associable, :dependent => :destroy
  has_many :users, through: :associations
  has_one :primary_address, -> { where :address_type => "primary" }, :class_name => "Address", :as => :addressable, :dependent => :destroy
  has_one :mailing_address, -> { where :address_type => "mailing" }, :class_name => "Address", :as => :addressable, :dependent => :destroy
  has_many :addresses, :class_name => "Address", :as => :addressable, :dependent => :destroy
  has_many :listing_view_histories
  has_one :basic_offer, -> { where :offer_type => :basic }, :class_name => "LicenseeOffer", :foreign_key => "licensee_id"
  has_one :basic_active_offer, -> { where :active => true, :offer_type => :basic }, :class_name => "LicenseeOffer", :foreign_key => "licensee_id"
  has_many :licensee_quick_offers, :class_name => "LicenseeQuickOffer"
  has_many :languages, :through => :licensee_languages
  has_many :owners, -> { where("current = ? AND contact_type ILIKE 'owner_%'", true).order(:contact_type) }, :class_name => "Contact", :as => :contactable
  has_many :alarm_companies, -> { where "contact_type ILIKE alarm_1'" }, :class_name => "Contact", :as => :contactable
  has_many :emergency_contacts, -> { where "contact_type = 'emergency_1'" }, :class_name => "Contact", :as => :contactable
  has_many(:hours, :class_name => "Hour", :foreign_key => "licensee_id", :dependent => :destroy) do
    # 'on' is implemented here to avoid hitting the DB hundreds of times for
    #  each page displaying the business_hours select UI, which was happening
    #  when using scope in the business_hour model.
    def on(day_name)
      self.select{|bh| bh.day.name.downcase == day_name.to_s.downcase }
    end
  end
  has_many :emailgroups, :as => :owner
  has_many :sponsors

  has_many :secondary_e2g2_categories, -> { where('licensee_e2g2_categories.rank != 1').order("licensee_e2g2_categories.rank") }, :through => :licensee_e2g2_categories, :source => :e2g2_category
  has_many :primary_e2g2_categories, -> { where('licensee_e2g2_categories.rank = 1') }, :through => :licensee_e2g2_categories, :source => :e2g2_category
  has_many :events, :as => :hostable
  has_many :articles, :as => :authorable
  has_many :favorites, as: :favoriteable
  has_many :listing_images, -> { where image_type: :standard }, as: :imageable, class_name: 'Image'
  has_many :images, as: :imageable, dependent: :destroy
  has_many :posts, dependent: :destroy

  has_many :neighbourhood_business_affiliations, class_name:  'LicenseeNeighbourhoodAffiliation', foreign_key: :affiliated_organization_id
  has_many :business_affiliations, through: :neighbourhood_business_affiliations

  has_many :affiliated_neighbourhood_organizations, class_name: 'LicenseeNeighbourhoodAffiliation', foreign_key: :business_affiliation_id
  has_many :affiliated_organizations, through: :affiliated_neighbourhood_organizations

  has_one :licensee_additional_information
  has_many :user_requests, :as => :requestable, :dependent => :destroy


  after_touch() { tire.update_index }
  self.include_root_in_json = false

  accepts_nested_attributes_for :primary_address

  attr_accessible :description, :directory_name, :email, :fax, :latitude, :longitude, :public_phone, :tagline,
    :website_url, :premium, :home_based, :claimed, :token, :membership, :services, :products, :youtube_video_codes,
    :hours_opt_out, :assigned_to, :is_a_member, :licensee_type_id, :payment_note,
    :hours_note, :around_the_clock, :address_locked

  acts_as_taggable

  ################################
  # Validations
  ################################
  validates_presence_of :name, :on => :create, :message => "can't be blank"
  validates_presence_of :government_id, :on => :create, :message => "can't be blank"
  validates_presence_of :licensee_type_id, :on => :create, :message => "can't be blank"
  validates_presence_of :status, :on => :create, :message => "can't be blank"
  validates_length_of :tagline, :maximum => MAX_TAGLINE_LENGTH, :allow_nil => true, :message => "Should be less than {{count}}"
  validates_length_of :description, :maximum => MAX_DESCRIPTION_LENGTH, :allow_nil => true, :message => "Must not be more than #{MAX_DESCRIPTION_LENGTH} characters long!"

  validates :youtube_video_codes, length: { maximum: 1 }, unless: -> { city_sponsor_package? && orgs_package? }, youtube_video_codes: true

  ################################
  # Named Scopes
  ################################
  scope :unclaimed, -> { where("status = 'active' AND claimed = false") }
  scope :government, -> (government_id) { where("licensees.government_id = ?", government_id) }
  scope :active, -> { where(status: :active) }
  scope :sponsors_for, -> (category_id) {
    joins(sponsors: :sponsor_categories).where('sponsor_categories.e2g2_category_id' => category_id)
  }

  alias_attribute :title, :directory_name

  [:active].each do |method|
    define_method "#{method}?", -> { status == method }
  end

  def self.select_by_name(gov_id, query)
    government(gov_id).where("directory_name ILIKE ?", "%#{query}%").map(&:chosen)
  end

  def self.e2g2_category(e2g2_category)
    e2g2_category_ids = e2g2_category.self_and_descendants.pluck(:id)

    self
      .joins(:e2g2_categories)
      .where("licensees.status = ? AND e2g2_categories.id IN(?) AND (licensees.inside_city = ? OR licensees.inside_city IS NULL)", "active", e2g2_category_ids, true)
      .order("licensees.premium DESC, licensees.directory_name ASC, licensees.name ASC")
  end

  ################################
  # Callbacks
  ################################
  before_create :generate_token
  before_save :populate_directory_name, :clean_phone_and_fax, :set_claimed_at, :generate_referral_code
  after_create :cache_license_no
  after_validation :format_website_url_protocol
  after_commit :cache_search_columns
  after_update :generate_url_stub, if: -> { directory_name_changed? }

  ################################
  # Enumerators (Autovalidated)
  ################################
  symbolize :status, :i18n => false, :in => [
    :inactive,        # license has NOT been approved or is beeing reviewd by gov
    :active,          # license has been approved
    :user_inactive,   # owner chose to remove the listing
    :expired]
  symbolize :origin, :i18n => false, :in => [
    :import,          # records were likely imported from city license data
    :manual_entry,    # record was manually created using and admin UI
    :license_process] # standard process by which new license/licensee data gets created
  symbolize :geocode_status, :i18n => false, :in => [
    :unknown,         # status is not known, may be a new record
    :failure,         # geo retrieval failed
    :success]         # geo was set by proper retrieval and is correct

  attr_accessible :url_stub, :hours

  #pagination
  cattr_reader :per_page
  @@per_page = 25

  ################################
  # Search
  ################################
  include Tire::Model::Search
  include Tire::Model::Callbacks
  require "aggregations.rb"

  settings analysis: {
    char_filter: { 
      quotes: {
        type: 'mapping',
        mappings: [ 
          '\\u0091=>\\u0027',
          '\\u0092=>\\u0027',
          '\\u2018=>\\u0027',
          '\\u2019=>\\u0027',
          '\\u201B=>\\u0027'
        ]
      }
    },
    filter: {
      index_shingle_filter: {
        type: 'shingle',
        token_seperator: ''
      },
      search_shingle_filter: {
        type: 'shingle',
        token_seperator: '',
        output_unigrams: false,
        output_unigrams_if_no_shingles: true
      },
      e2g2_edge_ngram: {
        type: 'edge_ngram',
        side: 'front',
        min_gram: 3,
        max_gram: 15
      },
      e2g2_word_delimiter: { 
        type: 'word_delimiter', 
        generate_number_parts: false, 
        split_on_numerics: false 
      },
      english_stop: {
        type: 'stop',
        language: '_english_'
      },
      english_stemmer: {
        type: 'stemmer',
        language: 'english'
      },
      english_possesive_stemmer: {
        type: 'stemmer',
        language: 'possessive_english'
      }
    },
    analyzer: {
      e2g2_default: {
        type: 'custom',
        tokenizer: 'standard',
        filter: ['classic', 'e2g2_word_delimiter', 'english_possesive_stemmer', 'lowercase', 'english_stop', 'english_stemmer', 'asciifolding'],
        char_filter: ['quotes', 'html_strip']
      },
      e2g2_index_shingle: {
        type: 'custom',
        tokenizer: 'standard',
        filter: ['classic', 'e2g2_word_delimiter', 'english_possesive_stemmer', 'lowercase', 'english_stop', 'english_stemmer', 'asciifolding', 'index_shingle_filter'],
        char_filter: ['quotes', 'html_strip']
      },
      e2g2_keyword: {
        type: 'custom',
        tokenizer: 'keyword',
        filter: ['lowercase', 'english_stemmer'],
        char_filter: ['quotes', 'html_strip']
      },
      e2g2_search_shingle: {
        type: 'custom',
        tokenizer: 'standard',
        filter: ['classic', 'e2g2_word_delimiter', 'english_possesive_stemmer', 'lowercase', 'english_stop', 'english_stemmer', 'asciifolding', 'search_shingle_filter'],
        char_filter: ['quotes', 'html_strip']
      }
    }
  }

  mapping dynamic: 'false' do
    # filters
    indexes :id,            type: 'integer',    index: :not_analyzed
    indexes :government_id, type: 'integer',    index: :not_analyzed
    indexes :inside_city,   type: 'boolean',    index: :not_analyzed, null_value: false
    indexes :premium,       type: 'boolean',    index: :not_analyzed, null_value: false
    indexes :claimed,       type: 'boolean',    index: :not_analyzed, null_value: false
    indexes :assigned_to,   type: 'integer',    index: :not_analyzed
    indexes :start_date,    type: 'date',       index: :not_analyzed
    indexes :status,        type: 'string',     index: :not_analyzed, null_value: 'inactive' 
    indexes :images_count,  type: 'integer',    index: :not_analyzed, null_value: 0
    indexes :offers_count,  type: 'integer',    index: :not_analyzed, null_value: 0
    indexes :location,      type: 'geo_point',  index: :not_analyzed, lat_lon: true
    indexes :mappable,      type: 'boolean',    index: :not_analyzed
    indexes :is_a_member,   type: 'boolean',    index: :not_analyzed
    indexes :corporate,     type: 'boolean',    index: :not_analyzed
    indexes :average_rating,type: 'integer',    index: :not_analyzed
    indexes :price_range,   type: 'integer',    index: :not_analyzed
    indexes :products,      type: 'string',     analyzer: 'e2g2_default'
    indexes :services,      type: 'string',     analyzer: 'e2g2_default'

    indexes :open_now, type: :nested do
      indexes :open_hour,   type: 'integer',    index: :not_analyzed
      indexes :close_hour,  type: 'integer',    index: :not_analyzed
    end

    # text matching
    indexes :directory_name, type: 'multi_field', fields: {
      directory_name: { type: 'string', analyzer: 'e2g2_default', copy_to: 'business_name' },
      partial:        { type: 'string', analyzer: 'e2g2_index_shingle', search_analyzer: 'e2g2_search_shingle' },
      autocomplete:   { type: 'string', analysis: 'e2g2_edge_ngram' }
    }
    indexes :business_name,         type: 'string',  index: :not_analyzed

    indexes :description,           type: 'string'
    indexes :description_length,    type: 'integer', index: :not_analyzed
    indexes :licensee_type_id,      type: 'integer', index: :not_analyzed

    indexes :offers, type: :nested do
      indexes :start_date,  type: 'date', index: :not_analyzed
      indexes :end_date,    type: 'date', index: :not_analyzed
    end

    indexes :product_priority, type: 'integer', index: :not_analyzed

    indexes :e2g2_categories_count, type: 'integer'
    indexes :e2g2_categories do
      indexes :id,    type: 'integer', index: :not_analyzed
      indexes :name,  type: 'multi_field', fields: {
        name:         { type: 'string', analyzer: 'e2g2_default' },
        partial:      { type: 'string', analyzer: 'e2g2_index_shingle', search_analyzer: 'e2g2_search_shingle' },
        autocomplete: { type: 'string', analysis: 'e2g2_edge_ngram' }
      }

      indexes :rank,            type: 'integer',  index: :not_analyzed, null_value: 5
      indexes :parent_names,    type: 'string',   analyzer: 'e2g2_default'
      indexes :parent_ids,      type: 'integer',  index: :not_analyzed
      indexes :keywords,        type: 'string',   analyzer: :e2g2_keyword
      indexes :keyword_count,   type: 'integer',  index: :not_analyzed, null_value: 0
      indexes :children_count,  type: 'integer',  index: :not_analyzed, null_value: 0
    end

    indexes :primary_e2g2_category_ids, type: 'integer',  index: :not_analyzed
    indexes :licensee_tags,             type: 'string',   index: :not_analyzed
    indexes :licensee_leads do
      indexes :rating,            type: 'string', index: :not_analyzed
      indexes :callback_date,     type: 'date',   index: :not_analyzed
      indexes :primary_language,  type: 'string', index: :not_analyzed
      indexes :disposition,       type: 'string', index: :not_analyzed
    end

    indexes :licensee_contracts do
      indexes :product_id,  type: 'integer',  index: :not_analyzed
      indexes :end_date,    type: 'date',     index: :not_analyzed
    end

    indexes :licenses do
      indexes :expiration_date, type: 'date', index: :not_analyzed
    end

    indexes :events do
      indexes :event_type,  type: 'string', index: :not_analyzed
      indexes :start_at,    type: 'date',   index: :not_analyzed
      indexes :end_at,      type: 'date',   index: :not_analyzed
    end
  end

  def to_indexed_json(options = {})
    as_indexed_json(options).to_json
  end

  def as_indexed_json(options = {})
    {
      id:                         id,
      government_id:              government_id,
      directory_name:             directory_name,
      inside_city:                inside_city?,
      premium:                    is_premium?,
      claimed:                    claimed?,
      assigned_to:                assigned_to,
      start_date:                 start_date,
      status:                     status,
      images_count:               images_count,
      offers_count:               licensee_offers_count,
      location:                   location,
      mappable:                   display_map?,
      is_a_member:                is_a_member,
      corporate:                  corporate?,
      average_rating:             average_rating,
      description:                description,
      description_length:         description.to_s.length,
      price_range:                licensee_additional_information.try(:price_range),
      licensee_type_id:           licensee_type_id,
      offers: licensee_offers.where(active: true, draft: false).map {|o|
        {
          start_date: o.start_date,
          end_date:   o.end_date,
        }
      },
      e2g2_categories: licensee_e2g2_categories.reject {|c| c.e2g2_category.nil? }.map {|c| 
        { 
          id:             c.e2g2_category_id,
          name:           c.e2g2_category.name, 
          rank:           c.rank, 
          keywords:       c.e2g2_category.keywords, 
          keyword_count:  c.e2g2_category.keywords.length, 
          children_count: c.e2g2_category.children_count, 
          parent_names:   c.e2g2_category.parent_names 
        }
      },
      e2g2_categories_count: licensee_e2g2_categories_count,
      primary_e2g2_category_ids: licensee_e2g2_categories.reject {|c| c.rank != 1 }.map(&:e2g2_category_id),
      licensee_tags: tags.map(&:name),
      licensee_leads: licensee_leads.map {|l|
        {
          rating:           l.rating,
          callback_date:    l.callback_date,
          primary_language: l.primary_language,
          disposition:      l.disposition
        }
      },
      licensee_contracts: licensee_contracts.map {|c|
        {
          product_id: c.product_id,
          end_date:   c.end_date
        }
      },
      licenses: licenses.map {|l|
        {
          expiration_date: l.expiration_date
        }
      },
      events: events.map {|e|
        {
          event_type: e.event_type,
          start_at:   e.start_at,
          end_at:     e.end_at
        }
      },
      open_now: open_hours_data,
      products: products[0...5],
      services: services[0...5],
      product_priority:  current_contract.try(:priority)
    }
  end

  def directory_name
    self[:directory_name].to_s.strip
  end

  def description_text
    Nokogiri::HTML(description).text
  end

  def open_hours_data
    hours.inject([]) do |hours_data, hour|
      hours_data << { open_hour: hour.open_time_as_int,
                      close_hour: hour.close_time_as_int }
    end
  end

  def self.open_hours_query
    range_query start_field: "open_now.open_hour",
                end_field: "open_now.close_hour",
                current: Hour.current_time_as_int
  end

  def self.active_offers_query
    range_query start_field: 'offers.start_date',
                end_field: 'offers.end_date',
                current: Date.today.to_s(:db)
  end

  def self.range_query(options)
    Tire::Search::Query.new do
      filtered do
        query { all }
        filter :range, options[:start_field] => { lte: options[:current] }
        filter :range, options[:end_field]   => { gte: options[:current] }
      end
    end
  end

  def self.search(params)
    query_term    = tire.escaped_query_string(params[:q].presence || params[:query].presence)
    includes      = params[:include].present? ? { include: params[:include] } : (!params[:load].nil? ? params[:load] : true)
    category_ids  = (Array(params[:e2g2_category_ids]) + E2g2Category.children_for_parents(params[:e2g2_category_parent_ids])).compact

    tire.search(load: includes, page: params[:page], per_page: params[:per_page]) do
      query do
        function_score do
          # custom scoring (filter boosting)
          max_boost 8.0
          score_mode 'multiply'

          # boosts
          function { filter :range, images_count: { from: 2 }; boost_factor 1.3 }
          function { filter :range, licensee_offers_count: { from: 1, to: 5 }; boost_factor 1.4 }
          function { filter :term, claimed: true; boost_factor 1.3 }
          function { filter :term, inside_city: true; boost_factor 1.4 }
          function { filter :term, home_based: true; boost_factor 0.3 }
          function { filter :term, mappable: true; boost_factor 1.6 }
          function { filter :term, premium: true; boost_factor 2 }
          function { filter :range, e2g2_categories_count: { from: 1, to: 3 }; boost_factor 1.2 }

          # penalties
          function { filter :range, description_length: { to: 500 }; boost_factor 0.5 }
          function { filter :range, e2g2_categories_count: { from: 6 }; boost_factor 0.5 }

          fields_to_match = [
            'directory_name^2', 'directory_name.partial^1.2',
            'e2g2_categories.name^1.8', 'e2g2_categories.name.partial^1.2',
            'e2g2_categories.parent_names^1.6'
          ]

          # search criteria
          query do
            filtered do
              # term matching
              query do
                if query_term.present?
                  dis_max do
                    query do
                      match fields_to_match, query_term, {
                        type:                   'best_fields',
                        tie_breaker:            0.3,
                        operator:               'and',
                        fuzziness:              0,
                        slop:                   1,
                        minimum_should_match:   '65%'
                      }
                    end

                    query do
                      match 'e2g2_categories.keywords', query_term, {
                        type:      'phrase',
                        operator:  'and',
                        slop:      1,
                      }
                    end

                    query do
                      match 'products', query_term, {
                        type:      'phrase',
                        operator:  'and',
                        slop:      1,
                      }
                    end

                    query do
                      match 'services', query_term, {
                        type:      'phrase',
                        operator:  'and',
                        slop:      1,
                      }
                    end
                  end
                else
                  all
                end
              end

              # filters
              filter :terms,        id: params[:ids] if params[:ids]
              filter :not,          { terms: { id: params[:exclude_ids] } } if params[:exclude_ids]
              filter :terms,        government_id: params[:government_ids] if params[:government_ids].present?
              filter :terms,        licensee_tags: params[:tags] if params[:tags]
              filter :term,         government_id: params[:government_id] if params[:government_id].present?
              filter :term,         inside_city: params[:inside_city] if params[:inside_city].present?
              filter :term,         status: params[:status] if params[:status].present?
              filter :geo_distance, location: { lat: params[:latitude], lon: params[:longitude]}, distance: "#{params[:distance] || 10}mi" if params[:latitude].present? && params[:longitude].present?
              filter :terms,        'e2g2_categories.id' => category_ids if !category_ids.empty?
              filter :terms,        'primary_e2g2_category_ids' => category_ids if params[:primary_e2g2_category] && category_ids.present?
              filter :missing,      field: :e2g2_categories if params[:no_categories]
              filter :range,        e2g2_categories_count: params[:e2g2_categories_count] if params[:e2g2_categories_count].present?
              filter :term,         premium: params[:premium] unless params[:premium].nil?
              filter :term,         claimed: params[:claimed] if params[:claimed].present?
              filter :term,         is_a_member: params[:is_a_member] if params[:is_a_member].present?
              filter :term,         assigned_to: params[:assigned_to] if params[:assigned_to].present?
              filter :range,        start_date: { gte: params[:start_date]['start_month'], lte: params[:start_date]['end_month'] } if params[:start_date].present?
              filter :term,         'licensee_leads.rating' => params[:lead_rating] if params[:lead_rating].present?
              filter :range,        'licensee_leads.callback_date' => {from: params[:lead_callback_date].beginning_of_day, to: params[:lead_callback_date].end_of_day} if params[:lead_callback_date]
              filter :range,        'licensee_contracts.end_date' => {from: params[:contract_end_date].first, to: params[:contract_end_date].last} if params[:contract_end_date]
              filter :exists,       field: 'licensee_contracts.product_id' if params[:purchased_package]
              filter :term,         'licensee_contracts.product_id' => params[:purchased_package_type] if params[:purchased_package_type]
              filter :term,         'licensee_leads.primary_language' => params[:lead_primary_language] if params[:lead_primary_language].present?
              filter :term,         licensee_type_id: params[:licensee_type_id] if params[:licensee_type_id].present?
              filter :term,         corporate: params[:corporate] if params[:corporate].present?
              if params[:lead_disposition] == 'do_not_call'
                filter :term,         'licensee_leads.disposition' => params[:lead_disposition]
              elsif params[:lead_disposition] == 'exclude_do_not_call'
                filter :not,          { term: { 'licensee_leads.disposition' => 'do_not_call' } }
              end
              filter :range,        'licenses.expiration_date' => { gte: params[:license_expiration_date]['start_month'], lt: params[:license_expiration_date]['end_month'] } if params[:license_expiration_date].present?
              filter :term,         'events.event_type' => params[:event_type] if params[:event_type].present?
              filter :range,        'events.start_at'   => { gte: params[:event_date]['start_month'] } if params[:event_date].present?
              filter :range,        'events.end_at'   => { lte: params[:event_date]['end_month'] } if params[:event_date].present?

              unless params[:deals_status].nil?
                if params[:deals_status]
                  filter :nested, { path: 'offers', query: Licensee.active_offers_query.to_hash }
                else
                  filter :not, { nested: { path: 'offers', query: Licensee.active_offers_query.to_hash } }
                end
              end

              filter :nested, { path: 'open_now', query: Licensee.open_hours_query.to_hash } if params[:open_now].present?
              filter :term, price_range: params[:price_range] if params[:price_range].present?
            end
          end
        end
      end
      # sorting / ordering
      sort = params[:sort].to_s.downcase == 'distance' && (params[:latitude].blank? || params[:longitude].blank?) ? nil : params[:sort].to_s.downcase
      case sort
        when 'name'       then sort { by :directory_name, params[:order] }
        when 'rating'     then sort { by :average_rating, params[:order] }
        when 'relevance'  then sort { by :_score, params[:order] }
        when 'category'   then sort { by :primary_category_name, params[:order]; by :directory_name, params[:order] }
        when 'distance'   then sort { by :_geo_distance, location: "#{params[:latitude]},#{params[:longitude]}", unit: 'mi' }
        when 'premium'    then sort { by :premium, "desc"; by :_score, params[:order] }
        else                   sort { by :product_priority, "desc"; by :premium, "desc"; by :_score, params[:order] }
      end

      if params[:categories_count]
        facet :categories_count do
          terms 'e2g2_categories.id', size: E2g2Category.all.size
        end
      end

      unless params[:find_duplicates].blank?
        aggregations :dedup do
          terms :business_name, size: 0, min_doc_count: 2
          aggregations :dedup_docs do
            top_hits size: 50
          end
        end
      end
    end
  end

  def self.category_ids(options)
    search(options.merge categories_count: true)
      .facets["categories_count"]["terms"].map {|i| i["term"]}
  end

  [:header_images, :standard_images, :mobile_images].each do |method|
    define_method method do
      is_premium? ? images.where(image_type: method.to_s.split('_').first) : []
    end
  end

  alias :listing_images :standard_images

  def about_us_image
    images.where(image_type: :about_us).first if is_premium?
  end

  def logo
    images.where(image_type: :logo).first if is_premium?
  end

  def images
    is_premium? ? super : []
  end

  def jobs
    articles.where({article_type: :jobs, draft: false})
  end

  def news
    articles.where({article_type: :news, draft: false})
  end

  def volunteer_opportunities
    articles.where({article_type: :volunteer_opportunities, draft: false})
  end

  def is_department?
    # Maybe need better solution
    GovernmentResources::Department.where("params LIKE ?", "% _#{self.id}%").first.present?
  end

  def newsfeed(options = {})
    options = { type: 'all', time: Time.now }.merge options

    types_and_relations = { 'events' => :events,
                            'news' => :news,
                            'jobs' => :jobs,
                            'volunteers' => :volunteer_opportunities,
                            'reviews' => :licensee_reviews,
                            'coupons' => :licensee_offers,
                            'promotions' => :licensee_quick_offers,
                            'opportunities' => [:jobs, :volunteer_opportunities]
                          }

    select_from = ->(method) do
      send(method).where("created_at < ? AND draft=false", options[:time])
                  .order("created_at DESC")
                  .limit(NEWSFEED_PER_PAGE).to_a
    end
    if options[:type] == 'all'
      data = select_from.call(:events) + select_from.call(:articles)
      data.sort {|x, y| y.created_at <=> x.created_at}
    elsif relation = types_and_relations[options[:type]]
      objects = []
      if relation.is_a? (Array)
        relation.each {|r| objects += select_from.call r}
        objects.sort! {|x, y| y.updated_at <=> x.updated_at}
      else
        objects = select_from.call relation
      end
      objects
    else
      []
    end[0..(NEWSFEED_PER_PAGE-1)]
  end

  def dashboard_newsfeed(params)
    type = params[:type] && !params[:type].empty? ? params[:type] : "all"

    if params[:category_id].present?
      category_ids = E2g2Category.all_children_categories_ids(params[:category_id])
      licensee_ids = Licensee.find_by_sql(["select l.id from licensees as l inner join licensee_e2g2_categories as le on l.id = le.licensee_id inner join e2g2_categories as e on e.id = le.e2g2_category_id WHERE l.government_id = #{self.government_id} AND e.id in (?) ", category_ids]).collect(&:id)
    else
      licensee_ids = Licensee.select("id").find_all_by_government_id(self.government_id).collect(&:id)
    end
    modify_params = params.merge({licensee_ids: licensee_ids, licensee_polymorphic_type: self.class.name.downcase})
    posts = []
    posts += Article.search(modify_params) if ["all", "news", "jobs", "reviews", "volunteer_opportunities"].include? type
    posts += Event.search(modify_params) if ["all", "events"].include? type
    posts += LicenseeOffer.search(modify_params) if ["all", "coupons"].include? type
    if ["all", "requests", "promotions"].include? type
      e2g2_category_ids_to_s = e2g2_category_ids.map(&:to_s)
      LicenseeQuickOffer.search(modify_params).each do |licensee_quick_offer|
        posts.push(licensee_quick_offer) if licensee_quick_offer.display?(self)
      end
    end

    posts.sort {|x, y| y.updated_at <=> x.updated_at}
  end

  def chosen
    attrs = [name]
    attrs << primary_address.city_name if primary_address
    attrs << licenses.first.gov_acct_no if licenses.present?

    { value: id, text: attrs.join(', ') }
  end

  def location
    { 
      lat: latitude || 0, lon: longitude || 0
    }
  end

  def latitude
    read_attribute(:latitude) || primary_address.try(:latitude)
  end

  def longitude
    read_attribute(:longitude) || primary_address.try(:longitude)
  end

  def primary_category
    licensee_e2g2_categories.find {|c| c.rank.to_i == 1 }.try(:e2g2_category)
  end

  def primary_category_name
    primary_category.try(:name)
  end

  def primary_category_keywords
    primary_category.try(:keywords)
  end

  def primary_category_parent_name
    primary_category.try(:parent).try(:name)
  end

  def primary_category_parent_keywords
    primary_category.try(:parent).try(:keywords)
  end

  def category_names
    e2g2_categories.map(&:name)
  end

  def category_keywords
    e2g2_categories.map(&:keywords)
  end

  def category_parent_names
    e2g2_categories.map {|c| c.parent.name }
  end

  def category_parent_keywords
    e2g2_categories.map {|c| c.parent.keywords }
  end

  def inside_city=(is_inside_city)
    write_attribute(:inside_city, is_inside_city.to_s.strip =~ /(true|t|yes|y|1|inside)$/i ? true : false)
  end

  def home_based=(is_home_based)
    write_attribute(:home_based, is_home_based.to_s.strip =~ /(true|t|yes|y|1)$/i ? true : false)
  end

  def set_claimed_at
    self.claimed_at = Time.now if claimed_changed? && claimed
  end

  def to_param
    "#{id}-#{read_attribute(:url_stub) ? read_attribute(:url_stub) : listing_name.strip.downcase.gsub('&', ' and ').gsub(/[^0-9a-z ]/, '').gsub(/\s+/, '_')}"
  end
  alias :url_stub :to_param

  def keywords
    e2g2_categories.map {|category| category.full_name.split(' : ').join(', ') }.join(', ')
  end

  def competitors(search = '')
    return [] if e2g2_category_ids.empty?

    self.class.all(
      :joins      => "INNER JOIN licensee_e2g2_categories ON licensee_e2g2_categories.licensee_id = licensees.id AND licensee_e2g2_categories.e2g2_category_id IN(#{e2g2_category_ids.join(',')})",
      :conditions => ["licensees.government_id = ? AND licensees.id != ? AND licensees.status = ? AND lower(name) LIKE ?", government_id, id, "active", "%#{search.downcase}%"],
      :order      => "licensee_e2g2_categories.rank ASC, COUNT(licensee_e2g2_categories.id) DESC",
      :group      => "licensees.id, licensee_e2g2_categories.rank",
      :include    => ["favorites", "user_redeemed_offers"],
    )
  end

  # create other day that is not weekdays
  def create_otherday(day_name)
    day_new = Day.create(:name => day_name, :day_type => "others")
    is_saved = day_new.save!
    return is_saved
    rescue ActiveRecord::RecordNotFound
      raise "cannot create a other day at Business"
  end

  def has_hours?
    self.hours.count > 0 || self.around_the_clock
  end

  def hours_of_operation
      hours.all(:include => [:day],:joins => [:day], :conditions => {:days => {:day_type => :weekday}}, :order => 'days.order ASC, hours.open_hour ASC')
  end

  def special_hours_of_operation
      hours.all(:include => [:day], :joins => [:day], :conditions => ["days.day_type != 'weekday'"], :order => 'days.order ASC, hours.open_hour ASC')
  end

  def hours=(days)
    hours.delete_all # Is there a better way of updating the hours?

    days.each_with_index do |day_hours|
      day_id = day_hours[0]

      day_hours[1].each do |hour|
        open_time   = Struct::TimeItem.parse(hour['open'])
        close_time  = Struct::TimeItem.parse(hour['close'])

        if open_time && close_time
          hour_params = { :open_time => open_time, :close_time => close_time, :day_id => day_id }
          new_record? ? hours.build(hour_params) : hours.create(hour_params)
        end
      end
    end
  end

  # returns the business hours for the given day
  def open_days
    hours.map{|hour| hour.day.name}.uniq
  end

  # returns whether the business is open on the given day at the specified time
  # See BusinessHour#includes_time? for the format of the time argument
  def open_on?(day_name, time)
    if around_the_clock
      true 
    else
      # check each range of business hours to see if it includes the given time
      hours.on(day_name).any?{|bh| bh.includes_time?(time) }
    end
  end

  # returns a string of all the time ranges for a given day
  def hours_on_day(day_name, use_leading_zero = false, show_minutes_if_zero = true)
    hours.on(day_name).map{|d| d.times(use_leading_zero, show_minutes_if_zero) }.join(', ')
  end

  def hours_on_day_id(day_name, use_leading_zero = false, show_minutes_if_zero = true)
    day_id = Day.find_by_name(day_name)
    hours.on(day_id).map{|d| d.times(use_leading_zero, show_minutes_if_zero) }.join(', ')
  end

  def notation_for_day(day_name)
    day = hours.on(day_name).first
    return day.notation if day.notation.present?

    notation = nil
    range = (1..day.day_id-1).to_a

    hours.where(day_id: range).order('day_id desc').each do |prev_day|
      if prev_day.open_hour == day.open_hour \
        && prev_day.open_minute == day.open_minute \
        && prev_day.close_hour == day.close_hour \
        && prev_day.close_minute == day.close_minute \
        && prev_day.day_id == range.pop

        notation = prev_day.notation if prev_day.notation.present?
      else
        break
      end
    end

    notation
  end

  def top_ranked_category
    e2g2_categories.first
  end

  def create_image(image)
    return if image.nil?
    return is_saved
    rescue ActiveRecord::RecordNotFound
      raise "cannot create a image at Licensee"
  end

  def is_premium?
    [:government, :school, :organization, :cityhall].include?(licensee_type) || premium
  end

  def is_status_inactive?
    self.status.eql?(:inactive)
  end

  def available_languages
    self.languages.map {|l| l.native_name}
  end

  def listing_name
    if self.directory_name
      self.directory_name
    elsif self.operating_name
      self.operating_name
    else
      self.name
    end
  end

  # enforce protocol on website url
  def format_website_url_protocol
    url = self.website_url

    unless url.nil? || url.empty?
      if url =~ /^https?:\/\//
        self.website_url = url
      else
        self.website_url = 'http://' + url
      end
    end

    url
  end

  def display_address?(show_invalid = true)
    !home_based? && inside_city? && primary_address && primary_address.valid? && ((show_invalid && primary_address.status != :error) || primary_address.status == :verified)
  end

  def display_map?(show_invalid = false)
    latitude.present? && longitude.present?
  end

  # generate a system-wide unique url stub (i.e. e2g2.com/pacos_tacos)
  def generate_url_stub(save=true)
    stub = listing_name.strip.downcase.gsub('&', ' and ').gsub(/[^0-9a-z ]/, '').gsub(/\s+/, '_')
    self.update_column :url_stub, stub if save
    stub
  end

  Product.all.each do |product|
    # define methods: basic_package?, face_to_the_place_package?,
    # category_sponsor_package?, city_sponsor_package?, orgs_package?
    define_method "#{product.identifier}?", -> { licensee_contracts.pluck(:product_id).include? product.id }
  end

private

  def generate_token
    self.token = SecureRandom.hex(3).downcase
    generate_token unless Licensee.find_by_token(self.token).nil? # Ensure uniqueness of the token..
  end

  def generate_referral_code
    return unless status.to_sym == :active && referral_code.nil?

    self.referral_code = SecureRandom.hex(3)
    generate_referral_code unless Licensee.find_by_referral_code(self.referral_code).nil? # Ensure uniqueness of the referral_code..
  end
end
