require "r_settings"

ActiveRecord::Base.class_eval do
  def self.has_r_settings
    class_eval do
      has_many :r_settings, :class_name => "RSettings", :foreign_key => :object_id, :conditions => {:object_type => self.base_class.to_s}
      def settings
        RSettings.for_object(self)
      end




      named_scope :with_settings, :joins => "JOIN r_settings ON (r_settings.object_id = #{self.table_name}.#{self.primary_key} AND
                                                               r_settings.object_type = '#{self.base_class.name}')",
                  :select => "DISTINCT #{self.table_name}.*"

      named_scope :with_settings_for, lambda { |var| { :joins => "JOIN settings ON (settings.object_id = #{self.table_name}.#{self.primary_key} AND
                                                                                    settings.object_type = '#{self.base_class.name}') AND
                                                                                    settings.var = '#{var}'" } }

      named_scope :without_settings, :joins => "LEFT JOIN settings ON (settings.object_id = #{self.table_name}.#{self.primary_key} AND
                                                                       settings.object_type = '#{self.base_class.name}')",
                  :conditions => 'settings.id IS NULL'

      named_scope :without_settings_for, lambda { |var| { :joins => "LEFT JOIN settings ON (settings.object_id = #{self.table_name}.#{self.primary_key} AND
                                                                                            settings.object_type = '#{self.base_class.name}') AND
                                                                                            settings.var = '#{var}'",
                                                          :conditions => 'settings.id IS NULL' } }
    end
  end
end

