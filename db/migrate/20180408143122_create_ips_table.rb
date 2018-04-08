class CreateIpsTable < ActiveRecord::Migration[5.1]
  def change
    create_table :ips do |t|
      t.string :host
      t.string :ip
      t.timestamps
    end
  end
end
