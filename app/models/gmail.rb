class Gmail < ActiveRecord::Base
  has_many :tasks

  validates :email, uniqueness: true
  validates :email, :password, presence: true

  SEARCH_BY = %w(email bought_from password)
  SEARCH_RULE = 'cont'

  scope :unmarked, -> { where("status IS null OR status = ''") }
  scope :not_bad, -> { where("status is NULL OR status <> ?", 'bad') }
  scope :available_for, ->(type, provider) {
    not_bad.where("#{provider.downcase}_#{type.downcase}_used_time < ? AND task_type = ?", Settings.gmail.used_for["#{provider.downcase}_#{type.downcase}"].to_i, "#{provider.downcase}_#{type.downcase}")
  }
  scope :good, -> { where("status IS NULL OR status =''") }

  scope :with_used, ->(value) {
    conditon_hash = { 'greatest' => '> 60', '0' => '= 0', '1' => '= 1' }
    conditon = conditon_hash[value] ? conditon_hash[value] : "< #{value}"
    where("(gmails.google_edit_used_time + gmails.google_create_used_time + gmails.apple_create_used_time) #{conditon}")
  }

  def self.filtered_data(params)
    return all if params.values.all? {|v| v.empty? }
    obj = self
    obj = with_used(params[:used]) unless params[:used].empty?
    unless params[:task_type].empty?
      value = params[:task_type] == 'unassigned' ? nil : params[:task_type]
      obj = obj.where(task_type: value)
    end
    obj = obj.where(source: params[:source]) unless params[:source].empty?
    obj = obj.good if params[:status] == 'good'
    obj = obj.where(status: 'bad') if params[:status] == 'bad'
    obj
  end

  def self.change_status(id, status)
    gmail = Gmail.find(id)
    if status[:checked] == 'false'
      gmail.update_attribute(:status, nil)
    else
      gmail.update_attribute(:status, "#{status[:value]}")
    end
    gmail
  end

  def used
    google_create_used_time + google_edit_used_time + apple_create_used_time
  end

  def usage_statistic
    {Google_Edit: google_edit_used_time, Google_Create: google_create_used_time, Google_Reverts: google_reverts_used_time,
     Apple_Create: apple_create_used_time}
  end

  def usage_statistic_for type, provider
    usage_statistic["#{provider}_#{type}".to_sym].to_i
  end

  def first_time_usage? type, provider
    usage_statistic_for(type, provider).zero?
  end

  def can_be_used? type, provider
    used_time_for(type, provider) < Settings.gmail.used_for["#{provider.downcase}_#{type.downcase}"].to_i
  end

  def used_time_for type, provider
    read_attribute "#{provider.downcase}_#{type.downcase}_used_time"
  end

  def self.next_available_for(type, provider)
    available_for(type, provider).first
  end

  def DT_RowId
    "row_#{self.id}" if self.persisted?
  end
end
