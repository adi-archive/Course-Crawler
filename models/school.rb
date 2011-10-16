class School
  include DataMapper::Resource
  property :id, Serial
  property :abbreviation, String, :length => 256
  property :name, String, :length => 256

  ABRVS = {
    :cc => 'CC',
    :en => 'EN',
    :bc => 'BC',
    :gsas => 'GSAS',
    :ce => 'CE',
    :sipa => 'SIPA',
    :gs => 'GS'
  }

end
