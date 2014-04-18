# encoding: utf-8
module VoshodAvtoImport

  class BaseParser

    def initialize(saver)
      @saver = saver
    end # initialize

    def start_element(name, attrs = [])
      @str = ""
    end # start_element

    def end_element(name)
    end # end_element

    def characters(str)
      @str << str.squish unless str.blank?
    end # characters

    def error(string)
      @saver.log "[XML Errors] #{string}"
    end # error

    def warning(string)
      @saver.log "[XML Warnings] #{string}"
    end # warning

    def end_document
    end # end_document

    private

    #
    # Validations
    #
    def catalog_valid?

      return false if @catalog.empty?

      if @catalog[:id].blank?
        @saver.log "[Errors] Не найден идентификатор у каталога: #{@catalog.inspect}"
        return false
      end

      if @catalog[:dep_code].blank?
        @saver.log "[Errors] Не найден код отдела у каталога: #{@catalog.inspect}"
        return false
      end

      true

    end # catalog_valid?

    def item_valid?

      return false if @item.empty?

      if @item[:id].blank?
        @saver.log "[Errors] Не найден идентификатор у товара: #{@item.inspect}"
        return false
      end

      if @item[:name].blank?
        @saver.log "[Errors] Не найдено название у товара: #{@item.inspect}"
        return false
      end

      if @item[:price].blank?
        @saver.log "[Errors] Не найдена цена у товара: #{@item.inspect}"
        return false
      end

      if @item[:catalog_id].blank?
        @saver.log "[Errors] Не найден каталог у товара: #{@item.inspect}"
        return false
      end

      true

    end # item_valid?

  end # BaseParser

end # VoshodAvtoImport
