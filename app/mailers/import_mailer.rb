# encoding: utf-8
class ImportMailer < ActionMailer::Base

  default from: "order@v-avto.ru",
          to:   "ivan@anlas.ru, 1c@v-avto.ru"

  def full_import(department_names, log_dump)

    @departments  = department_names
    @time         = (::Time.now + 2.hours).strftime("%H:%M, %d-%m-%Y")
    @log_dump     = log_dump

    mail(:subject => "Выгрузка из 1С на сайт v-avto.ru")

  end # full_import

end # ImportMailer
