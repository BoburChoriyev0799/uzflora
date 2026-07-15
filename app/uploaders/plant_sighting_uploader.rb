# encoding: utf-8

class PlantSightingUploader < BaseUploader
  process :resize_to_fill => [700, 524]
  process :quality => 80

  version :small do
    process :resize_to_fill => [256, 192]
  end

  version :thumb do
    process :resize_to_fill => [154, 116]
  end

  def store_dir
    "images/plant_sighting/#{mounted_as}/#{salted_reproducible_id}"
  end

  def extension_white_list
    %w(jpg jpeg png)
  end

  # Talab: 10 MB'dan katta rasm yuklanmasin.
  def size_range
    0..10.megabytes
  end

  private

  def salt
    ENV['PLANT_SIGHTING_CARRIERWAVE_SALT']
  end
end
