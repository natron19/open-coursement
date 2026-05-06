class CreateCourseOutlines < ActiveRecord::Migration[8.1]
  def change
    create_table :course_outlines, id: :uuid do |t|
      t.references :course_brief, null: false, foreign_key: true, type: :uuid
      t.references :user,         null: false, foreign_key: true, type: :uuid
      t.string  :title,      null: false
      t.text    :body,       null: false
      t.boolean :is_draft,   null: false, default: false
      t.text    :gemini_raw, null: false
      t.timestamps null: false
    end

    add_index :course_outlines, :is_draft
  end
end
