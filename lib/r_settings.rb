class RSettings < ActiveRecord::Base
  class SettingNotFound < RuntimeError;
  end
  class InappropriateType < RuntimeError;
  end
  class InappropriateSerializer < RuntimeError;
  end

  @@data_types = %w( integer float string boolean )

  @@each_record_expires_in = 24.hours
  @@all_records_expire_in = 24.hours  
  @@serializer = YAML

  validates_inclusion_of :data_type, :in => @@data_types
  validates_presence_of :data_type
  validates_presence_of :key
  validates_uniqueness_of :key, :scope => [:object_type, :object_id]

  attr_accessible :formatted_value, :key, :data_type, :object_id, :object_type, :description
  attr_readonly :key, :data_type

  after_save :delete_cache
  after_save :write_cache

  before_destroy :delete_cache

  def self.method_missing(method, *args)
    method_name = method.to_s
    super(method, *args)

  rescue NoMethodError
    if method_name =~ /=$/
      var_name = method_name.gsub('=', '')
      value = args.first
      self[var_name] = value

    else
      self[method_name]

    end
  end

  def self.[](key)
    self.check_cache
    parameter = Rails.cache.fetch(File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, key.to_s), :expires_in => RSettings.each_record_expires_in) {
      self.object(key.to_s)
    }
    unless parameter.nil?
      parameter.formatted_value
    else
      raise SettingNotFound, "Setting \"#{key}\" not found"
    end
  end

  def self.[]=(key, value)
    parameter = self.object(key.to_s)
    if parameter
      parameter.value = value
      parameter.save
    else
      p = self.object_scoped.new do |p|
        p.key = key.to_s
        p.value = value
      end
      p.save
    end
  end

  def self.destroy(key)
    p = self.object(key.to_s)
    unless p.nil?
      p.destroy
    else
      raise SettingNotFound, "Setting \"#{key}\" not found"
    end
  end

  #Get settings for object. It is similar to call Object.settings
  def self.for_object(object)
    RSettingsForObject.set_object(object)
  end

  def self.all(like = nil)
    options = like ? { :conditions => "key LIKE '%#{like}%'"} : {}
    object_scoped.find(:all, options)
  end

  def self.all_keys_and_values
    settings = find(:all, :select => 'key, value')

    result = {}
    settings.each do |setting|
      result[setting.key] = setting.value
    end
    result.with_indifferent_access
  end


  def self.data_types
    @@data_types
  end

  def self.each_record_expires_in
    @@each_record_expires_in
  end

  def self.each_record_expires_in=(v)
    @@each_record_expires_in = v
  end

  def self.all_records_expire_in
    @@all_records_expire_in
  end

  def self.all_records_expire_in=(v)
    @@all_records_expire_in = v
  end

  def self.serializer
    @@serializer
  end

  def self.serializer=(v)
    if [YAML, Marshal].include? v
      @@serializer = v
    else
      raise InappropriateSerializer
    end
  end

  def to_param
    self.key
  end

  def value
    v = read_attribute(:value)
    RSettings.serializer::load(v) unless v.nil?
  end

  def value=(v)
    v_data_type = TypeCaster.cast_data_type(v.class.to_s.downcase)
    if data_type == v_data_type || data_type.nil?
      write_attribute(:value, RSettings.serializer::dump(v))
      write_attribute(:data_type, v_data_type)
    else
      raise InappropriateType, "Parameter is \"#{data_type}\". And value - \"#{v_data_type}\""
    end
  end

  def formatted_value
    self.value
  end

  def formatted_value=(v)
    self.value = TypeCaster.class_eval("treat_as_#{self.data_type}(v)")
  end

  def self.object(key)
    object_scoped.find_by_key(key.to_s)
  end

  def self.object_scoped
    RSettings.scoped_by_object_type_and_object_id(object_type, object_id)
  end

  def self.object_id
    nil
  end

  def self.object_type
    nil
  end

  #Clears cache for a particular RSetting
  def delete_cache
    Rails.cache.delete(File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, key.to_s))
    logger.info("RSettings. Cleared cache for #{File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, key.to_s)}")
    true
  end

  #Writes cache for a particular RSetting
  def write_cache
    Rails.cache.write(File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, key.to_s), self, :expires_in => RSettings.each_record_expires_in)
    logger.info("RSettings. Written cache for #{File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, key.to_s)}")
  end

  private

  def self.check_cache
    if !$parameters_cached_on.nil? && $parameters_cached_on <= DateTime.now - 1.hour
      Rails.cache.delete('settings')
      self.find(:all).each do |parameter|
        Rails.cache.write(File.join('settings', object_type.to_s.downcase.pluralize, object_id.to_s, parameter.key.to_s), parameter)
      end

      $parameters_cached_on = DateTime.now
    end
  end

  class TypeCaster
    def self.cast_data_type(data_type)
      case data_type
        when 'fixnum', 'bignum':
          'integer'
        when 'trueclass', 'falseclass':
          'boolean'
        else
          data_type
      end
    end

    def self.treat_as_string(string)
      string.chomp
    end

    def self.treat_as_integer(string)
      string.to_i
    end

    def self.treat_as_float(string)
      string.to_f
    end

    def self.treat_as_boolean(string)
      if string.match(/true|t|yes|y|1/i) != nil
        true
      elsif string.match(/false|f|no|n|0/i) != nil
        false
      else
        nil
      end
    end

  end

  class RSettingsForObject < RSettings
    def self.object_id
      @object.nil? ? nil: @object.id
    end

    def self.object_type
      @object.nil? ? nil: @object.class.base_class.to_s
    end

    def self.set_object(object)
      @object = object
      self
    end
  end
end


