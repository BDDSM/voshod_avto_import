# encoding: utf-8
VoshodAvtoImport::Engine.routes.draw do

  get  '1c_import(/:base)'      => 'import#index'
  post '1c_import(/:base)'      => 'import#save_file'

  get  '1c_import_mag(/:base)'  => 'import#index'
  post '1c_import_mag(/:base)'  => 'import#save_file_mag'

end # draw
