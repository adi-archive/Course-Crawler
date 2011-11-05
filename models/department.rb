class Department
  include DataMapper::Resource
  property :id, Serial
  property :abbreviation, String, :length => 256
  property :title, String, :length => 256

  has n, :sections
end


