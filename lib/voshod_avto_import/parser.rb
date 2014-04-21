# encoding: utf-8
module VoshodAvtoImport

  # Класс-шаблон по разбору товарных xml-файлов
  class XmlParser < Nokogiri::XML::SAX::Document

    def initialize(saver)

      @saver    = saver
      @parser   = nil
      @str      = ""

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

        when /Аксессуары/i   then
          @parser = ::VoshodAvtoImport::Ask1c7Parser.new(@saver)

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

      case @str

        # Челябинк
        when 'db996b9e-3d2f-11e1-84e7-00237d443107' then
          @parser = ::VoshodAvtoImport::ChelImportParser.new(@saver)

        # Екатеринбург
        when '95912c90-191b-11de-bee1-00167682119b' then
          @parser = ::VoshodAvtoImport::EkbImportParser.new(@saver)

      end # case

    end # get_1c8_import

    def get_1c8_offers(name)

      return unless @init_1c8_offers
      @init_1c8_offers = false

      case @str

        # Челябинк
        when 'db996b9e-3d2f-11e1-84e7-00237d443107' then
          @parser = ::VoshodAvtoImport::ChelOffersParser.new(@saver)

        # Екатеринбург
        when '95912c90-191b-11de-bee1-00167682119b' then
          @parser = ::VoshodAvtoImport::EkbImportParser.new(@saver)

      end # case

    end # get_1c8_offers

  end # XmlParser

end # VoshodAvtoImport

=begin

      @level              = 0
      @tags               = {}
     @catalogs_item_map  = {}

=end

=begin
      attrs  = ::Hash[attrs]
      @str   = ""

      @level += 1
      @tags[@level] = name

      case name

        # 1C 8 (дополнительно)
        when 'Каталог'        then
          parse_partial(attrs)

        when 'ПакетПредложений' then
          set_price_processing

        # 1C 8 (цены)
        when 'ТипыЦен'        then
          start_parse_prices

        when 'ТипЦены'        then
          start_parse_price

        # 1C 8 (свойства)
        when 'Свойства'       then
          start_parse_properties

        when 'Свойство'       then
          start_parse_property

        # 1C 8 (каталоги)
        when 'Классификатор'  then
          start_parse_catalogs

        when 'Группа'         then
          up_catalog_level
          start_parse_catalog

        when 'Группы'         then
          stop_parse_catalog
          change_catalog_parent

        # 1C 8 (товары)
        when 'Товары'         then
          start_parse_items

        when 'Товар'          then
          start_parse_item

        # 1C 8 (свойства товаров)
        when 'ЗначенияСвойства' then
          start_parse_item_property

        # 1С 8 (цены для товаров)
        when 'Предложение'    then
          start_parse_item_extend

        when 'Цена'           then
          start_parse_item_price

        # 1C 7.7
        when 'doc'            then
          start_parse_catalogs
          tag_doc(attrs)

        when 'catalog'        then
          tag_catalog(attrs)

        when 'item'           then
          tag_item(attrs)

      end # case
=end


=begin
      @level -= 1

      case name

        # 1C 8 (каталоги)
        when 'Классификатор'  then
          stop_parse_catalogs

        when 'Группа'         then
          stop_parse_catalog
          down_catalog_level

        # 1С 8 (товары)
        when 'Товары'         then
          stop_parse_items

        when 'Товар'          then
          stop_parse_item

        # 1C (общее)
        when 'Ид'             then
          grub_catalog(:id)
          grub_item(:id)
          grub_catalog_for_item
          grub_property(:id)
          grub_item_property(:id)
          grub_price(:id)
          grub_item_id_for_extend

        when 'Отдел'          then
          grub_item_dep_for_extend

        when 'Значение'       then
          grub_item_property(:value)

        when 'Отдел'          then
          grub_item(:department)

        when 'Артикул'        then
          grub_item(:mog)

        when 'АртикулПроизводителя'   then
          grub_item(:mog_vendor)

        when 'Наименование'   then
          grub_item(:name)
          grub_catalog(:name)
          grub_property(:name)
          grub_price(:name)

        when 'КодСтранаПроисхождения' then
          grub_item(:country_code)

        when 'СтранаПроисхождения'    then
          grub_item(:country)

        when 'НомерГТД'       then
          grub_item(:gtd)

        when 'Производитель'  then
          grub_item(:vendor)

        when 'БазоваяЕдиница' then
          grub_item(:unit)

        when 'ДополнительноеОписаниеНоменклатуры' then
          grub_item(:additional_info)

        # 1C 8 (свойства)
        when 'Свойства'       then
          stop_parse_properties

        when 'Свойство'       then
          stop_parse_property

        # 1C 8 (свойства товаров)
        when 'ЗначенияСвойства' then
          stop_parse_item_property

        # 1C 8 (цены)
        when 'ТипыЦен'        then
          stop_parse_prices

        when 'ТипЦены'        then
          stop_parse_price

        # 1С 8 (цены для товаров)
        when 'Предложение'    then
          stop_parse_item_extend

        when 'Цена'           then
          stop_parse_item_price

        when 'ИдТипаЦены'     then
          grub_item_price(:id)

        when 'ЦенаЗаЕдиницу'  then
          grub_item_price(:price)

        # 1C 8 (количество товарв)
        when 'Количество'     then
          grub_item_count_fot_extend

        # 1C 7.7
        when 'doc'            then
          stop_parse_catalogs
          save_items_1c77

      end # case
=end

=begin
    def get_price(price)
      price.squish.try(:to_f)
    end # get_price

    def parent_tag
      @tags[@level+0] || ""
    end # parent_tag

    def change_catalog_parent

      return if @start_parse_catalogs != true
      @catalog_parent_id[@catalog_level] = @catalog[:id]

    end # change_catalog_parent

    #
    # 1C 7.7
    #
    def tag_doc(attrs)

      @catalog_dep_code = ::VoshodAvtoImport::CATALOGS_DEPS[attrs['department']]
      deps              = ::VoshodAvtoImport::DEPS[@catalog_dep_code] || {}

      @catalog          = {

        dep_code: @catalog_dep_code,
        name:     deps[:name] || 'Неизвестно',
        id:       "dep",
        pos:      deps[:pos]

      }

      @catalogs_array << @catalog if catalog_valid?

      @saver.set_partial(false)

    end # tag_doc

    def tag_catalog(attrs)

      parent_id = attrs['parent'].squish

      @catalog              = {}
      @catalog[:parent_id]  = parent_id.blank? ? "dep" : parent_id
      @catalog[:dep_code]   = @catalog_dep_code
      @catalog[:id]         = attrs['id']
      @catalog[:name]       = attrs['name'].squish

      @catalogs_item_map[@catalog[:id]] = @catalog[:dep_code]
      @catalogs_array << @catalog if catalog_valid?

    end # tag_catalog

    def tag_item(attrs)

      @item = {

        id:         attrs["id"],
        dep_code:   @catalog[:dep_code],
        catalog_id: attrs["catalog"],
        name:       attrs["name"].try(:squish),
        price:      attrs["price"].try(:squish),
        count:      attrs["count"].try(:to_i) || 0,
        mog:        attrs["artikul"],
        mog_vendor: attrs["vendor_artikul"],
        unit:       attrs["unit"]

      }

      (@items ||= []) << @item if item_valid?

    end # tag_item

    def save_items_1c77

      @items ||= []

      @items.each do |item|
        @saver.save_item(item)
      end

      @items = []

    end # save_items_1c77

    def reset_datas!

      @catalog_level        = 0
      @catalog_parent_id    = {}
      @catalog              = {}
      @catalogs_array       = []

    end # reset_datas!

    #
    # 1C 8
    #
    def start_parse_catalogs

      return if @start_parse_catalogs == true

      @start_parse_catalogs = true
      reset_datas!

    end # start_parse_catalogs

    def stop_parse_catalogs

      return if @start_parse_catalogs != true

      @start_parse_catalogs = false

      @catalogs_array.each do |catalog|
        @saver.save_catalog(catalog)
      end

      reset_datas!

    end # stop_parse_catalogs

    def start_parse_catalog

      return if @start_parse_catalogs != true

      @start_parse_catalog = true
      @catalog             = {}

    end # start_parse_catalog

    def stop_parse_catalog

      return if @start_parse_catalog != true

      @start_parse_catalog = false

      if @catalog_level == 1

        @catalog_dep_code = ::VoshodAvtoImport::CATALOGS_DEPS[@catalog[:name]]
        deps              = ::VoshodAvtoImport::DEPS[@catalog_dep_code] || {}
        @catalog[:name]   = deps[:name] || 'Неизвестно'
        @catalog[:pos]    = deps[:pos]

      end

      @catalog[:parent_id]  = @catalog_parent_id[@catalog_level-1]
      @catalog[:dep_code]   = @catalog_dep_code

      @catalogs_item_map[@catalog[:id]] = @catalog[:dep_code]

      @catalogs_array << @catalog if catalog_valid?

    end # stop_parse_catalog

    def up_catalog_level
      @catalog_level += 1
    end # up_catalog_level

    def down_catalog_level
      @catalog_level  -= 1
    end # down_catalog_level

    def grub_catalog(attr_name)
      @catalog[attr_name] = @str.squish if for_catalog?
    end # grub_catalog

    def for_catalog?
      @start_parse_catalog == true && parent_tag == "Группа"
    end # for_catalog?

    def parse_partial(attrs)

      @saver.set_partial(
        [true, 'true'].include?(attrs['СодержитТолькоИзменения'])
      )

    end # parse_partial

    def set_price_processing
      @saver.set_price_processing(true)
    end # set_price_processing

    def start_parse_items

      return if @start_parse_items == true

      @start_parse_items  = true
      @items              = []

    end # start_parse_items

    def stop_parse_items

      return if @start_parse_items != true

      @start_parse_items = false

      @items.each do |item|
        @saver.save_item(item)
      end

      @items = []

    end # stop_parse_items

    def start_parse_item

      return if @start_parse_items != true

      @start_parse_item = true
      @item             = {
        price: 0
      }

    end # start_parse_item

    def stop_parse_item

      return if @start_parse_item != true

      @start_parse_item = false

      @item[:dep_code]  = @catalogs_item_map[@item[:catalog_id]]
      @items << @item if item_valid?

    end # stop_parse_item

    def for_item?
      @start_parse_item == true && parent_tag == "Товар"
    end # for_item?

    def grub_item(attr_name)
      @item[attr_name] = @str.squish if for_item?
    end # grub_item

    def id_group_for_item?
      @start_parse_item == true && parent_tag == 'Группы'
    end # id_group_for_item?

    def grub_catalog_for_item(attr_name = :catalog_id)
      @item[attr_name] = @str.squish if id_group_for_item?
    end # grub_catalog_for_item

    def start_parse_properties

      return if @start_parse_properties == true

      @start_parse_properties = true
      @properties             = {}

    end # start_parse_properties

    def stop_parse_properties

      return if @start_parse_properties != true

      @start_parse_properties = false

    end # stop_parse_properties

    def start_parse_property

      return if @start_parse_properties != true

      @start_parse_property = true
      @property             = {}

    end # start_parse_property

    def stop_parse_property

      return if @start_parse_property != true

      @start_parse_property = false
      @properties[ @property[:id] ] = @property[:name]

    end # stop_parse_property

    def for_property?
      @start_parse_property == true && parent_tag == "Свойство"
    end # for_property?

    def grub_property(attr_name)
      @property[attr_name] = @str.squish if for_property?
    end # grub_property

    def start_parse_item_property

      return if @start_parse_item_property == true

      @start_parse_item_property  = true
      @item_property              = {}

    end # start_parse_item_property

    def stop_parse_item_property

      return if @start_parse_item_property != true

      @start_parse_item_property = false

      if @start_parse_item == true

        @item[:properties]  = @item_property
        @item_property      = {}

      end # if

    end # stop_parse_item_property

    def for_item_property?
      @start_parse_item_property == true && parent_tag == "ЗначенияСвойства"
    end # for_item_property?

    def grub_item_property(attr_name)

      return unless for_item_property?

      if attr_name == :id

        @last_key_property = @properties[@str.squish]
        @item_property[ @last_key_property ] = nil

      elsif attr_name == :value && !@last_key_property.nil?

        @item_property[ @last_key_property ] = @str.squish
        @last_id_property = nil

      end # if

    end # grub_item_property

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
        @item_extend[@item_last_id][:dep_code] = ::VoshodAvtoImport::ITEMS_DEPS[@str.squish]
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
      return if price_id.nil?

      @item_extend[@item_last_id][ price_id ] = @item_price[:price]

    end # stop_parse_item_price

    def for_item_price?
      @start_parse_item_price == true && parent_tag == "Цена"
    end # for_item_price?

    def grub_item_price(attr_name)
      @item_price[attr_name] = @str.squish if for_item_price?
    end # grub_item_price

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
=end
