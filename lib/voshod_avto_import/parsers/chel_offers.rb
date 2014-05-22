# encoding: utf-8
module VoshodAvtoImport

  class ChelOffersParser < ::VoshodAvtoImport::BaseParser

    ITEMS_DEPS = {

      'Автохимия'   => 2,
      'Химия'       => 2,

      'Инструменты' => 3,
      'Инструмент'  => 3,

      'ВАЗ'         => 4,
      'ГАЗ'         => 5,
      'Иномарки'    => 6

    }.freeze

    def initialize(saver)

      super(saver)

      @level  = 0
      @tags   = {}

      set_price_processing

    end # initialize

    def start_element(name, attrs = [])

      super(name, attrs)

      attrs  = ::Hash[attrs]
      @level += 1
      @tags[@level] = name

      case name

        # 1C 8 (цены)
        when 'ТипыЦен'        then
          start_parse_prices

        when 'ТипЦены'        then
          start_parse_price

        # 1С 8 (цены для товаров)
        when 'Предложение'    then
          start_parse_item_extend

        when 'Цена'           then
          start_parse_item_price

      end # case

    end # start_element

    def end_element(name)

      @level -= 1

      case name

        # 1C (общее)
        when 'Ид'             then
          grub_price(:id)
          grub_item_id_for_extend

        when 'Отдел'          then
          grub_item_dep_for_extend

        # 1C 8 (цены)
        when 'ТипыЦен'        then
          stop_parse_prices

        when 'ТипЦены'        then
          stop_parse_price

        # 1С 8 (цены для товаров)
        when 'Предложение'    then
          stop_parse_item_extend

        when 'Наименование'   then
          grub_price(:name)

        when 'Цена'           then
          stop_parse_item_price

        when 'ИдТипаЦены'     then
          grub_item_price(:id)

        when 'ЦенаЗаЕдиницу'  then
          grub_item_price(:price)

        # 1C 8 (количество товарв)
        when 'Количество'     then
          grub_item_count_fot_extend

      end # case

    end # end_element

    private

    def parent_tag
      @tags[@level+0] || ""
    end # parent_tag

    def set_price_processing
      @saver.set_price_processing(true)
    end # set_price_processing

    def start_parse_prices

      return if @start_parse_prices == true

      @start_parse_prices = true
      @prices             = {}

    end # start_parse_prices

    def stop_parse_prices

      return if @start_parse_prices != true
      @start_parse_prices = false

    end # stop_parse_prices

    def start_parse_price

      return if @start_parse_prices != true

      @start_parse_price = true
      @price             = {}

    end # start_parse_price

    def stop_parse_price

      return if @start_parse_price != true

      @start_parse_price      = false
      @prices[ @price[:id] ]  = @price[:name]

    end # stop_parse_price

    def for_price?
      @start_parse_price == true && parent_tag == "ТипЦены"
    end # for_price?

    def grub_price(attr_name)
      @price[attr_name] = @str.squish if for_price?
    end # grub_price

    def start_parse_item_extend

      return if @start_parse_item_extend == true

      @start_parse_item_extend = true
      @item_extend             = {}

    end # start_parse_item_extend

    def stop_parse_item_extend

      return if @start_parse_item_extend != true

      @start_parse_item_extend = false

      @item_extend.each do |id, values|
        @saver.save_item_extend(id, values)
      end

    end # stop_parse_item_extend

    def grub_item_id_for_extend

      if @start_parse_item_extend == true && parent_tag == "Предложение"

        @item_last_id               = @str.squish
        @item_extend[@item_last_id] = {}

      end

    end # grub_item_id_for_extend

    def grub_item_dep_for_extend

      if @start_parse_item_extend == true && parent_tag == "Предложение"
        @item_extend[@item_last_id][:dep_code] = ITEMS_DEPS[@str.squish]
      end

    end # grub_item_dep_for_extend

    def grub_item_count_fot_extend

      if @start_parse_item_extend == true && parent_tag == "Предложение"
        @item_extend[@item_last_id][:count] = @str.squish
      end

    end # grub_item_count_fot_extend

    def start_parse_item_price

      return if @start_parse_item_extend != true

      @start_parse_item_price = true
      @item_price             = {}

    end # start_parse_item_price

    def stop_parse_item_price

      return if @start_parse_item_price != true

      @start_parse_item_price = false

      price_id = @prices[ @item_price[:id] ]
      return if price_id.nil? || !['Опт'].include?(price_id)

      @item_extend[@item_last_id][:price] = @item_price[:price]

    end # stop_parse_item_price

    def for_item_price?
      (@start_parse_item_price == true) && (parent_tag == "Цена")
    end # for_item_price?

    def grub_item_price(attr_name)
      @item_price[attr_name] = @str.squish if for_item_price?
    end # grub_item_price

  end # ChelOffersParser

end # VoshodAvtoImport
