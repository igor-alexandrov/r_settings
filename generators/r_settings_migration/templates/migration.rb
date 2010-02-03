class <%= class_name %> < ActiveRecord::Migration
  def self.up
    create_table :r_settings, :force => true do |t|
      t.string :key, :null => false
      t.text   :value
      t.string :data_type, :null => true
      t.integer :object_id, :null => true
      t.string :object_type, :limit => 30, :null => true
      t.timestamps
    end

    add_index :r_settings, [ :object_type, :object_id, :key ], :uniq => true
  end

  def self.down
    drop_table :r_settings
  end
end