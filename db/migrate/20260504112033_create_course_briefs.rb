class CreateCourseBriefs < ActiveRecord::Migration[8.1]
  def change
    create_table :course_briefs, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string  :topic,           null: false, limit: 200
      t.string  :target_audience, null: false, limit: 200
      t.string  :skill_level,     null: false
      t.text    :extra_notes
      t.timestamps null: false
    end
  end
end
