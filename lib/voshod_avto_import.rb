# encoding: utf-8
require 'logger'
require 'zip'
require 'fileutils'
require 'yaml'
require 'nokogiri'

module VoshodAvtoImport

  extend self

  FILE_LOCK = '/tmp/voshod_avto_import.lock'.freeze

  DEPS = {

    1 => {

      name:     'Аксессуары и электроника',
      pos:      0,
      email:    ["aks@v-avto.ru"],
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
      email:    ["instr@v-avto.ru"],
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
      email:    ["inomarki@v-avto.ru"],
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

  def login(v = nil)

    @login = v unless v.blank?
    @login

  end # login

  def password(v = nil)

    @pass = v unless v.blank?
    @pass

  end # password

  alias :pass :password

  def import_map(v = nil)

    @import_map = v if v.is_a?(::Hash)
    @import_map

  end # import_map

  def backup_dir(v = nil)

    @backup_dir = v unless v.blank?
    @backup_dir

  end # backup_dir

  def log_dir(v = nil)

    @log_dir = v unless v.blank?
    @log_dir || ::File.join(::Rails.root, "log")

  end # log_dir

  def wait(v = nil)

    @wait = v.abs if v.is_a?(::Fixnum)
    @wait || 5 * 60

  end # wait

  def run

    begin
      f = ::File.new(::VoshodAvtoImport::FILE_LOCK, ::File::RDWR|::File::CREAT, 0400)
      return if f.flock(::File::LOCK_EX) === false
    rescue ::Errno::EACCES
      return
    end

    begin
      ::VoshodAvtoImport::Manager.run
    ensure
      ::FileUtils.rm(::VoshodAvtoImport::FILE_LOCK, force: true)
    end

  end # run

  def full_update(v = nil)

    @full_update_callback = v if v.is_a?(::Proc)
    @full_update_callback

  end # full_update

  def partial_update(v = nil)

    @partial_update_callback = v if v.is_a?(::Proc)
    @partial_update_callback

  end # partial_update

  def backup_file_to_dir(file)

    return false if file.nil?
    return false if ::VoshodAvtoImport::backup_dir.nil?

    begin

      dir = Time.now.utc.strftime(::VoshodAvtoImport::backup_dir).gsub(/%[a-z]/, '_')

      ::FileUtils.mkdir_p(dir, mode: 0755) unless ::FileTest.directory?(dir)
      return false unless ::FileTest.directory?(dir)

      ::FileUtils.mv(file, dir)

    rescue SystemCallError
      log "Не могу переместить файл `#{::File.basename(file)}` в `#{dir}`"
    rescue => ex
      log ex.inspect
    ensure
      ::FileUtils.rm_rf(file)
    end

  end # backup_file_to_dir

  def log(msg = "")

    create_logger unless @logger
    @logger.error(msg)

    (@dump_log ||= "") << msg

    msg

  end # log

  def close_logger

    return unless @logger
    @logger.close
    @logger = nil

  end # close_logger

  def dump_log
    @dump_log || ""
  end # dump_log

  def clear_log
    @dump_log = nil
  end # clear_log

  private

  def create_logger

    return unless ::VoshodAvtoImport::log_dir && ::FileTest.directory?(::VoshodAvtoImport::log_dir)
    return if @logger

    ::FileUtils.mkdir_p(::VoshodAvtoImport::log_dir) unless ::FileTest.directory?(::VoshodAvtoImport::log_dir)
    log_file = ::File.open(
      ::File.join(::VoshodAvtoImport::log_dir, "import.log"),
      ::File::WRONLY | ::File::APPEND | ::File::CREAT
    )
    log_file.sync = true
    @logger = ::Logger.new(log_file, 'weekly')
    @logger

  end # create_logger

end # VoshodAvtoImport

require 'voshod_avto_import/version'
require 'voshod_avto_import/util'
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
