# encoding: utf-8
module VoshodAvtoImport

  class EkbImportParser < ::VoshodAvtoImport::BaseParser

    CITY_CODE = 2.freeze # Екатеринбург
    DEP_CODE  = 8.freeze

    def initialize(saver)

      super(saver)

      @level  = 0
      @tags   = {}

      start_parse_catalogs

    end # initialize

    def start_element(name, attrs = [])

      super(name, attrs)

      attrs  = ::Hash[attrs]
      @level += 1
      @tags[@level] = name

      case name

        # 1C 8 (дополнительно)
        when 'Каталог'        then
          parse_partial(attrs)

        # 1C 8 (свойства)
        when 'Свойства'       then
          start_parse_properties

        when 'Свойство'       then
          start_parse_property

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

      end # case

    end # start_element

    def end_element(name)

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
          grub_catalog_for_item(:catalog_id)
          grub_property(:id)
          grub_item_property(:id)

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

      end # case

    end # end_element

    private

    def reset_datas!

      @catalog_level        = 0
      @catalog_parent_id    = {}
      @catalog              = {}
      @catalogs_array       = []

    end # reset_datas!

    def parent_tag
      @tags[@level+0] || ""
    end # parent_tag

    def change_catalog_parent

      return if @start_parse_catalogs != true
      @catalog_parent_id[@catalog_level] = @catalog[:key_1c]

    end # change_catalog_parent

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
      @catalog             = {
        dep_code:   DEP_CODE,
        city_code:  CITY_CODE
      }

    end # start_parse_catalog

    def stop_parse_catalog

      return if @start_parse_catalog != true

      @start_parse_catalog = false

      @catalog[:key_1c]         = "#{DEP_CODE}-#{@catalog[:id]}"
      @catalog[:key_1c_parent]  = @catalog_parent_id[@catalog_level-1]
      @catalog[:city_code]      = CITY_CODE

      @catalogs_array << @catalog if catalog_valid?

    end # stop_parse_catalog

    def up_catalog_level
      @catalog_level += 1
    end # up_catalog_level

    def down_catalog_level
      @catalog_level -= 1
    end # down_catalog_level

    def grub_catalog(attr_name)
      @catalog[attr_name] = @str if for_catalog?
    end # grub_catalog

    def for_catalog?
      @start_parse_catalog == true && parent_tag == "Группа"
    end # for_catalog?

    def parse_partial(attrs)

      @saver.set_partial(
        [true, 'true'].include?(attrs['СодержитТолькоИзменения'])
      )

    end # parse_partial

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
        price:      0,
        dep_code:   DEP_CODE,
        city_coe:   CITY_CODE
      }

    end # start_parse_item

    def stop_parse_item

      return if @start_parse_item != true

      @start_parse_item = false

      unless (catalog_id = @item[:catalog_id].try(:squish)).nil?

        @item[:catalog_1c] = "#{DEP_CODE}-#{catalog_id}"

        unless (item_id = @item[:id].squish).blank?
          @item[:key_1c] = "#{DEP_CODE}-#{item_id}"
        end

      end

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

    def grub_catalog_for_item(attr_name)
      @item[attr_name] = @str if id_group_for_item?
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
      @property[attr_name] = @str if for_property?
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

        @last_key_property = @properties[@str]
        @item_property[ @last_key_property ] = nil

      elsif attr_name == :value && !@last_key_property.nil?

        @item_property[ @last_key_property ] = @str
        @last_id_property = nil

      end # if

    end # grub_item_property

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

  end # EkbImportParser

end # VoshodAvtoImport
