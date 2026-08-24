# frozen_string_literal: true

# birds.uz'dan qolgan eski qush-taksonomiya klasteri: `birds`, `comments`
# (faqat bird_id bilan — `belongs_to :bird` majburiy edi), `images`
# (qush turi rasmlari), `species`/`species_translations` (qush turlari,
# Plant bilan bog'liq EMAS), `categories`/`category_hierarchies`/
# `category_translations` (qush oila/turkumi). Ularga tayangan
# model/controller/view'lar (Bird, Species, Image, Comment, MapController,
# SpeciesController, CommentsController, SearchController va h.k.) shu
# bosqichdan OLDINGI commitda allaqachon o'chirilgan — shuning uchun bu
# yerda AR model klasslariga emas, faqat RAW SQL'ga tayanamiz (`Bird`,
# `Species` va h.k. konstantalari bu vaqtga kelib mavjud emas).
class DropBirdTaxonomyTables < ActiveRecord::Migration[7.1]
  # (jadval nomi, "0 emas" xabarida ko'rsatiladigan o'zbekcha nom)
  TABLES = {
    'comments' => "eski sharhlar (comments, bird_id bilan)",
    'images' => 'qush turi rasmlari (images)',
    'birds' => "qushlar (birds)",
    'category_hierarchies' => 'oila/turkum ierarxiyasi (category_hierarchies)',
    'category_translations' => "oila/turkum tarjimalari (category_translations)",
    'categories' => "oila/turkum (categories)",
    'species_translations' => "qush turi tarjimalari (species_translations)",
    'species' => 'qush turlari (species)'
  }.freeze

  def up
    TABLES.each do |table, label|
      count = select_value("SELECT COUNT(*) FROM #{table}")
      if count.to_i != 0
        raise ActiveRecord::IrreversibleMigration,
              "TO'XTATILDI: \"#{table}\" jadvalida #{count} ta yozuv bor (#{label}) — " \
              "kutilgan 0 emas. Bu jadval BO'SH emasligini tekshirmasdan o'chirib " \
              "bo'lmaydi (ma'lumot yo'qolishi mumkin). Avval nima uchun yozuv borligini " \
              "aniqlang, keyin bu migratsiyani qayta ko'rib chiqing."
      end
    end

    TABLES.each_key { |table| drop_table(table, force: :cascade) }
  end

  def down
    create_table :species, id: :serial, force: :cascade do |t|
      t.string :name_lat
      t.integer :category_id
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.integer :parent_id
      t.string :status
      t.boolean :show_map, default: true
      t.integer :position, default: 0
      t.boolean :single_subspecies, default: false
      t.index [:category_id], name: 'index_species_on_category_id'
      t.index [:parent_id], name: 'index_species_on_parent_id'
    end

    create_table :species_translations, force: :cascade do |t|
      t.integer :species_id, null: false
      t.string :locale, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.string :name
      t.text :description
      t.text :distribution
      t.text :biology
      t.text :reference
      t.index [:locale], name: 'index_species_translations_on_locale'
      t.index [:species_id], name: 'index_species_translations_on_species_id'
    end

    create_table :categories, id: :serial, force: :cascade do |t|
      t.string :type
      t.string :name_lat
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.integer :parent_id
      t.string :image
      t.integer :position, default: 0
      t.index [:parent_id], name: 'index_categories_on_parent_id'
    end

    create_table :category_hierarchies, id: false, force: :cascade do |t|
      t.integer :ancestor_id, null: false
      t.integer :descendant_id, null: false
      t.integer :generations, null: false
      t.index [:ancestor_id, :descendant_id, :generations], name: 'anc_desc_idx', unique: true
      t.index [:descendant_id], name: 'desc_idx'
    end

    create_table :category_translations, force: :cascade do |t|
      t.integer :category_id, null: false
      t.string :locale, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
      t.string :name
      t.text :description
      t.index [:category_id], name: 'index_category_translations_on_category_id'
      t.index [:locale], name: 'index_category_translations_on_locale'
    end

    create_table :birds, id: :serial, force: :cascade do |t|
      t.datetime :timestamp, precision: nil
      t.integer :species_id
      t.integer :user_id
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.text :address
      t.string :photo
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.boolean :published, default: false
      t.integer :expert_id
      t.integer :big_year, default: 0
      t.index [:species_id], name: 'index_birds_on_species_id'
      t.index [:user_id], name: 'index_birds_on_user_id'
    end

    create_table :images, id: :serial, force: :cascade do |t|
      t.string :image
      t.integer :species_id, null: false
      t.string :description
      t.string :author
      t.date :date
      t.string :address
      t.boolean :default, default: false
      t.index [:species_id], name: 'index_images_on_species_id'
    end

    create_table :comments, id: :serial, force: :cascade do |t|
      t.integer :bird_id
      t.integer :user_id
      t.text :text
      t.datetime :created_at, precision: nil, null: false
      t.datetime :updated_at, precision: nil, null: false
      t.index [:bird_id], name: 'index_comments_on_bird_id'
      t.index [:user_id], name: 'index_comments_on_user_id'
    end
  end
end
