namespace :voshod_avto_import do

  desc 'Обработка выгрузки'
  task :run => :environment do
    ::VoshodAvtoImport.run
  end # run

end # voshod_avto_import

# bundle exec rake voshod_avto_import:run
