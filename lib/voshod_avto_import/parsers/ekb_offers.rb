# encoding: utf-8
module VoshodAvtoImport

  class EkbOffersParser < ::VoshodAvtoImport::BaseParser

    CITY_CODE = 2.freeze # Екатеринбург
    DEP_CODE  = 8.freeze

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

        when 'ТипыЦен'        then
          start_parse_prices

        when 'ТипЦены'        then
          start_parse_price

        when 'Предложения'    then
          start_parse_items

        when 'Предложение'    then
          start_parse_item

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
          grub_item(:id)

        # 1C 8 (цены)
        when 'ТипыЦен'        then
          stop_parse_prices

        when 'ТипЦены'        then
          stop_parse_price

        when 'Предложение'    then
          stop_parse_item

        when 'Предложения'    then
          stop_parse_items

        when 'Наименование'   then
          grub_price(:name)
          grub_item(:name)

        when 'Артикул' then
          grub_item(:mog)

        when 'Цена'           then
          stop_parse_item_price

        when 'ИдТипаЦены'     then
          grub_item_price(:id)

        when 'ЦенаЗаЕдиницу'  then
          grub_item_price(:price)

        # 1C 8 (количество товарв)
        when 'Количество'     then
          grub_item(:count)

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

    def start_parse_items

      return if @start_parse_items == true

      @start_parse_items  = true
      @items              = []

    end # start_parse_items

    def stop_parse_items

      return if @start_parse_items != true

      @start_parse_items = false

      @items.each do |item|
        @saver.save_item_extend(item)
      end

      @items = []

    end # stop_parse_items

    def start_parse_item

      return if @start_parse_items != true

      @start_parse_item = true
      @item             = {
        city_code:  CITY_CODE,
        price:      0
      }

    end # start_parse_item

    def stop_parse_item

      return if @start_parse_item != true

      @start_parse_item = false

      @item[:dep_code]  = DEP_CODE

      unless (item_id = @item[:id].squish).blank?
        @item[:key_1c] = "#{DEP_CODE}-#{item_id}"
      end

      @items << @item if item_valid?(false)

    end # stop_parse_item

    def for_item?
      @start_parse_item == true && parent_tag == "Предложение"
    end # for_item?

    def grub_item(attr_name)
      @item[attr_name] = @str.squish if for_item?
    end # grub_item

    def start_parse_item_price

      return if @start_parse_item != true

      @start_parse_item_price = true
      @item_price             = {}

    end # start_parse_item_price

    def stop_parse_item_price

      return if @start_parse_item_price != true

      @start_parse_item_price = false

      price_id = @prices[ @item_price[:id] ]
      return if price_id.nil? || !['Ц2 - КРУПНЫЙ ОПТ'].include?(price_id)

      @item[:price] = @item_price[:price]

    end # stop_parse_item_price

    def for_item_price?
      (@start_parse_item_price == true) && (parent_tag == "Цена")
    end # for_item_price?

    def grub_item_price(attr_name)
      @item_price[attr_name] = @str.squish if for_item_price?
    end # grub_item_price

  end # EkbOffersParser

end # VoshodAvtoImport
