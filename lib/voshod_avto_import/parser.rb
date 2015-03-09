# encoding: utf-8
module VoshodAvtoImport

  # Класс-шаблон по разбору товарных xml-файлов
  class XmlParser < Nokogiri::XML::SAX::Document

    def initialize(saver, dir_base = nil)

      @saver      = saver
      @str        = ""
      @dir_base   = dir_base

    end # initialize

    def start_element(name, attrs = [])

      @str  = ""
      attrs = ::Hash[attrs]

      # Если парсер не установлен -- пытаемся его выбрать
      unless @parser

        case name

          # 1с7.7
          when 'doc'              then
            get_1c7(name, attrs)

          # 1c8 (import)
          when 'Классификатор'    then
            init_1c8_import(name, attrs)

          # 1c8 (offers)
          when 'ПакетПредложений' then
            init_1c8_offers(name, attrs)

        end # case

      end # unless

      # Если парсер выбран -- работаем.
      @parser.start_element(name, attrs) if @parser

    end # start_element

    def end_element(name)

      if @parser
        @parser.end_element(name)
      else

        case name

          # 1c8 (import)
          when 'Ид'               then
            get_1c8_import(name)

          # 1c8 (import)
          when 'ИдКлассификатора' then
            get_1c8_offers(name)

        end # case

      end # if

      @str = ""

    end # end_element

    def characters(str)
      @parser ? @parser.characters(str) : (@str << str.squish)
    end # characters

    def error(str)
      @parser.error(str) if @parser
    end # error

    def warning(str)
      @parser.warning(str) if @parser
    end # warning

    def end_document

      @parser.end_document if @parser

      @parser     = nil
      @department = 0

    end # end_document

    private

    def get_1c7(name, attrs)

      case attrs["department"]

        when /МАГНИТОГОРСК/i then
          @parser = ::VoshodAvtoImport::Mag1c7Parser.new(@saver)

      end # case

    end # get_1c7

    def init_1c8_import(name, attrs)
      @init_1c8_import = true
    end # init_1c8_import

    def init_1c8_offers(name, attrs)
      @init_1c8_offers = true
    end # init_1c8_offers

    def get_1c8_import(name)

      return unless @init_1c8_import
      @init_1c8_import = false

      case @dir_base

        # Магнитогорск
        when '/home/vavtoimportmag' then # '/Users/tyralion/work/voshod_avto/tmp/import_mag'
          @parser = ::VoshodAvtoImport::MagImportParser.new(@saver)

        # Екатеринбург
        when '/home/vavtoimportekb' then # '/Users/tyralion/work/voshod_avto/tmp/import_ekb'
          @parser = ::VoshodAvtoImport::EkbImportParser.new(@saver)

        # Челябинк
        else
          @parser = ::VoshodAvtoImport::ChelImportParser.new(@saver)

      end # case

    end # get_1c8_import

    def get_1c8_offers(name)

      return unless @init_1c8_offers
      @init_1c8_offers = false

      case @dir_base

        # Магнитогорск
        when '/home/vavtoimportmag' then # '/Users/tyralion/work/voshod_avto/tmp/import_mag'
          @parser = ::VoshodAvtoImport::MagOffersParser.new(@saver)

        # Екатеринбург
        when '/home/vavtoimportekb' then # '/Users/tyralion/work/voshod_avto/tmp/import_ekb'
          @parser = ::VoshodAvtoImport::EkbOffersParser.new(@saver)

        # Челябинк
        else
          @parser = ::VoshodAvtoImport::ChelOffersParser.new(@saver)

      end # case

    end # get_1c8_offers

  end # XmlParser

end # VoshodAvtoImport
