# encoding: utf-8
module VoshodAvtoImport

  # Класс-шаблон по разбору товарных xml-файлов
  class XmlParser < Nokogiri::XML::SAX::Document

    def initialize(saver, parsers_map)

      @saver        = saver
      @str          = ""
      @parsers_map  = parsers_map

    end # initialize

    def start_element(name, attrs = [])

      @str  = ""
      attrs = ::Hash[attrs]

      # Если парсер не установлен -- пытаемся его выбрать
      unless @parser

        case name

          # 1c8 (import)
          when 'Классификатор'    then init_1c8_import(name, attrs)

          # 1c8 (offers)
          when 'ПакетПредложений' then init_1c8_offers(name, attrs)

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
          when 'Ид'               then get_1c8_import(name)

          # 1c8 (import)
          when 'ИдКлассификатора' then get_1c8_offers(name)

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

    def init_1c8_import(name, attrs)
      @init_1c8_import = true
    end # init_1c8_import

    def init_1c8_offers(name, attrs)
      @init_1c8_offers = true
    end # init_1c8_offers

    def get_1c8_import(name)

      return unless @init_1c8_import
      @init_1c8_import = false

      @parser = @parsers_map[:import].send(:new, @saver)

    end # get_1c8_import

    def get_1c8_offers(name)

      return unless @init_1c8_offers
      @init_1c8_offers = false

      @parser = @parsers_map[:offers].send(:new, @saver)

    end # get_1c8_offers

  end # XmlParser

end # VoshodAvtoImport
