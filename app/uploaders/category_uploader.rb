# encoding: utf-8

class CategoryUploader < BaseUploader
  process resize_to_limit: [MAX_SOURCE_DIMENSION, MAX_SOURCE_DIMENSION]
  process :resize_to_fit => [100, 200]

end
