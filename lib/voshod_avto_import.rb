# encoding: utf-8
require 'logger'
require 'zip/zip'
require 'fileutils'
require 'yaml'
require 'nokogiri'

module VoshodAvtoImport

  extend self

  DEPS = {

    1 => {

      name:     'Аксессуары и электроника',
      pos:      0,
      email:    ["el@v-avto.ru"],
      translit: "Aksessuary_i_electronika"

    },

    2 => {

      name:     'Автохимия, масла',
      pos:      4,
      email:    ["him@v-avto.ru"],
      translit: "Avtokhimiya_masla"

    },

    3 => {

      name:     'Инструмент',
      pos:      1,
      email:    ["kat@v-avto.ru"],
      translit: "Instrument"

    },

    4 => {

      name:     'Запчасти ВАЗ',
      pos:      2,
      email:    ["yana@v-avto.ru", "nadejda@v-avto.ru"],
      translit: "Zapchasti_VAZ"

    },

    5 => {

      name:     'Запчасти ГАЗ, аккумуляторы',
      pos:      3,
      email:    ["gaz@v-avto.ru"],
      translit: "Zapchasti_GAZ_akkumulyatory"

    },

    6 => {

      name:     'Запчасти для иномарок',
      pos:      5,
      email:    ["nt@v-avto.ru", "inomarki@v-avto.ru"],
      translit: "Zapchasti_dlya_inomarok"

    },

    7 => {

      name:     'Магнитогорск',
      pos:      6,
      email:    ["mag@v-avto.ru"],
      translit: "Magnitogorsk"

    },

    8 => {

      name:     'Екатеринбург',
      pos:      7,
      email:    ["ekb@v-avto.ru"],
      translit: "Ekaterinburg"

    }

  }.freeze # DEPS

  def proc_name(v = nil)

    @proc_name = v unless v.blank?
    @proc_name

  end # proc_name

  def login(v = nil)

    @login = v unless v.blank?
    @login

  end # login

  def password(v = nil)

    @pass = v unless v.blank?
    @pass

  end # password

  alias :pass :password

  def import_dir(v = nil)

    @import_dir = v unless v.blank?
    @import_dir

  end # import_dir

  def backup_dir(v = nil)

    @backup_dir = v unless v.blank?
    @backup_dir

  end # backup_dir

  def daemon_log(v = nil)

    @daemon_log = v unless v.blank?
    @daemon_log

  end # daemon_log

  def log_dir(v = nil)

    @log_dir = v unless v.blank?
    @log_dir || ::File.join(::Rails.root, "log")

  end # log_dir

  def wait(v = nil)

    @wait = v.abs if v.is_a?(::Fixnum)
    @wait || 5 * 60

  end # wait

  def run
    ::VoshodAvtoImport::Manager.run
  end # run

  def full_update(v = nil)

    @full_update_callback = v if v.is_a?(::Proc)
    @full_update_callback

  end # full_update

  def partial_update(v = nil)

    @partial_update_callback = v if v.is_a?(::Proc)
    @partial_update_callback

  end # partial_update

end # VoshodAvtoImport

require 'voshod_avto_import/version'

require 'voshod_avto_import/ext'
require 'voshod_avto_import/mailer'

require 'voshod_avto_import/base_parser'

Dir[File.join(File.dirname(__FILE__), '/voshod_avto_import/parsers/**/*.rb')].each do |libs|
  require libs
end

require 'voshod_avto_import/parser'

require 'voshod_avto_import/worker'
require 'voshod_avto_import/manager'

if defined?(::Rails)
  require 'voshod_avto_import/engine'
  require 'voshod_avto_import/railtie'
end

