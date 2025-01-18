class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.string :title
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.string :filename
      t.string :file_type

      t.timestamps
    end
  end
end
