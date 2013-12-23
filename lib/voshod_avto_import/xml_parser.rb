# encoding: UTF-8
module VoshodAvtoImport

  # Класс-шаблон по разбору товарных xml-файлов
  class XmlParser < Nokogiri::XML::SAX::Document

    #
    # Парсер представляет из себя простой конечный автомат.
    # Разбор выгрузки из 1С8:
    # 1. Обработка дерева каталогов (Тег "Классификатор")
    # 2. Обработка товаров (Тег "Товар")
    #
    #
    def initialize(saver)

      @saver            = saver
      @price_types      = {}
      @item             = {}
      @level            = 0
      @tags             = {}
      @partial          = false
      @created_at       = nil

#      @validation_stage = 1

    end # initialize

    def start_element(name, attrs = [])

      attrs  = ::Hash[attrs]
      @str   = ""

      @level += 1
      @tags[@level] = name

      case name

        # 1C 8
        when 'Классификатор'  then
          start_parse_catalogs

        when 'Группа'         then
          up_catalog_level
          start_parse_catalog

        when 'Группы'         then
          stop_parse_catalog
          change_catalog_parent

        # 1C 7.7
        when 'doc'          then
          start_parse_catalogs
          tag_doc(attrs)

        when 'catalog'      then
          tag_catalog(attrs)

#        when 'item'         then tag_item(attrs)

        # 1C 8
#        when 'КоммерческаяИнформация' then
#          @created_at = ::DateTime.iso8601(attrs['ДатаФормирования'])

#        when 'ПакетПредложений','Каталог' then
#          @partial = attrs['СодержитТолькоИзменения'] == 'true' if attrs['СодержитТолькоИзменения']
#          @saver.partial = @partial

#        when 'Группа'       then start_catalog
#        when 'Группы'       then start_catalogs
#        when 'ТипЦены'      then start_parse_price
#        when 'Предложение'  then start_parse_item
#        when 'Товар'        then start_parse_item
#        when 'Цена'         then start_parse_item_price

      end # case

    end # start_element

    def end_element(name)

      @level -= 1

      case name

        # 1C 8
        when 'Классификатор'  then
          stop_parse_catalogs

        when 'Группа'         then
          stop_parse_catalog
          down_catalog_level

        when 'Ид'             then
          grub_catalog(:id)

        when 'Наименование'   then

          grub_catalog(:name)
          if @catalog_level == 1 && for_catalog?
            @catalog_dep_code = ::VoshodAvtoImport::CATALOGS_DEPS[@catalog[:name]]
          end

        # 1C 7.7
        when 'doc'            then
          stop_parse_catalogs

      end # case

=begin
      case name

        when 'Группа'         then stop_catalog
        when 'Группы'         then stop_catalogs

        when 'Ид'             then

          case parent_tag

            when 'Классификатор'  then
              # str - внутренний идентификатор в 1С
              # @saver.save_doc(::VoshodAvtoImport::DEPS_1V8[@str], @created_at)
              puts "@saver.doc #{::VoshodAvtoImport::DEPS_1V8[@str]}"
              @validation_stage = 1

            when 'Группа'         then
              grub_catalog('id')

          end

          @price_id  = @str  if for_price?
          grub_item('code_1c')
          grub_catalog_for_item

        when 'Наименование'   then

          grub_catalog('name')
          @price_name = @str if for_price?
          grub_item('name')

        when 'ИдКаталога'     then

          if parent_tag == 'ПакетПредложений'
            @validation_stage = 2
            @saver.save_doc(::VoshodAvtoImport::DEPS_1V8[@str], @created_at)
          end

        when 'Отдел'          then grub_item('department')
        when 'Артикул'        then grub_item('marking_of_goods')

        when 'АртикулПроизводителя' then
          grub_item('vendor_artikul')

        when 'ДополнительноеОписаниеНоменклатуры'
          grub_item('additional_info')

        when 'Производитель'  then grub_item('vendor')
        when 'Количество'     then grub_item('available')

        when 'БазоваяЕдиница' then grub_item('unit')

        when 'ЦенаЗаЕдиницу'  then
          @item_price     = get_price(@str)   if for_item_price?

        when 'ПроцентСкидки'  then
          @item_discount  = get_price(@str)   if for_item_price?

        when 'ИдТипаЦены'   then
          @item_price_id  = @str              if for_item_price?

        when 'ТипЦены'              then stop_parse_price
        when 'Предложение','Товар'  then stop_parse_item
        when 'Цена'                 then stop_parse_item_price

      end # case
=end

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

    def get_price(price)

      price.squish.try(:to_f)

#      price.
#        sub(/\A\s+/, "").
#        sub(/\s+\z/, "").
#        gsub(/(\s){2,}/, '\\1').
#        try(:to_f)

    end # get_price

    def parent_tag
      @tags[@level+0] || ""
    end # parent_tag

    def change_catalog_parent

      return if @start_parse_catalogs != true
      @catalog_parent_id[@catalog_level] = @catalog[:id]

    end # change_catalog_parent

=begin
    def for_item?
      (@start_parse_item && parent_tag == 'Предложение') || (@start_parse_item && parent_tag == 'Товар')
    end # for_item?

    def group_for_item?
      @start_parse_item && parent_tag == 'Группы'
    end

    def for_price?
      (@parse_price && parent_tag == 'ТипЦены')
    end # for_price?

    def for_item_price?
      (@start_parse_item_price && parent_tag == 'Цена')
    end # for_item_price?

    def grub_item(attr_name)
      @item[attr_name] = @str.xml_unescape if for_item?
    end # grub_item

    def grub_catalog(attr_name)
      @catalogs.last[attr_name] = @str if for_catalog?
    end

    def grub_catalog_for_item(attr_name = 'catalog')
      @item[attr_name] = @str.xml_unescape if group_for_item?
    end
=end

    #
    # 1C 7.7
    #
    def tag_doc(attrs)

      @catalog_tree     = {}
      @catalog_dep_code = ::VoshodAvtoImport::CATALOGS_DEPS[attrs['department']]
      @catalog_tree['']  = [{

        dep_code: @catalog_dep_code,
        name:     (::VoshodAvtoImport::DEPS[@catalog_dep_code] || {})[:name] || 'Неизвестно',
        id:       "dep"

      }]

    end # tag_doc

    def tag_catalog(attrs)

      parent_id = attrs['parent'].squish

      @catalog              = {}
      @catalog[:parent_id]  = parent_id.blank? ? "dep" : parent_id
      @catalog[:dep_code]   = @catalog_dep_code
      @catalog[:id]         = attrs['id']
      @catalog[:name]       = attrs['name'].squish

      @catalog_tree[parent_id] ||= []
      @catalog_tree[parent_id] << @catalog

    end # tag_catalog

=begin
    def tag_doc(attrs)
      @created_at = "#{attrs['data']} #{attrs['time']}".to_time2('%d.%m.%y %H:%M')
      @saver.save_doc(
        attrs['department'],
        @created_at
        )
    end

    def tag_catalog(attrs)
      save_catalog(attrs) if validate_1c_77_catalog(attrs)
    end

    def tag_item(attrs)
      save_item(attrs) if validate_1c_77_item(attrs)
    end

    def save_catalog(attrs)
      @saver.save_catalog(
        attrs['id'],
        attrs['name'],
        attrs['parent']
        )
    end

    def save_item(attrs)
      @saver.save_item(
        attrs['id'] || attrs['code_1c'],
        attrs['name'],
        attrs['artikul'] || attrs['marking_of_goods'],
        attrs['vendor_artikul'],
        (attrs['price'].try(:to_i) || attrs['supplier_wholesale_price']),
        (attrs['count'].try(:to_i) || attrs['available'].try(:to_i)),
        attrs['unit'],
        attrs['in_pack'].try(:to_i) || 1,
        attrs['catalog'],
        attrs['vendor'],
        attrs['additional_info'] || nil
      )
    end
=end

    #
    # 1C 8
    #

    def start_parse_catalogs

      return if @start_parse_catalogs == true

      @start_parse_catalogs = true

      # {
      #
      #   1 => {
      #
      #     id: "e358df46-4212-11e3-bc52-003048f6ad92",
      #     name: "00.Лузар",
      #     parent_id: nil
      #
      #   }
      #
      # }
      @catalog_tree         = {}

      @catalog_level        = 0
      @catalog_parent_id    = {}
      @catalog              = {}

    end # start_parse_catalogs

    def stop_parse_catalogs

      return if @start_parse_catalogs != true

      @start_parse_catalogs = false
      @catalog_parent_id    = {}
      @catalog              = {}

      @saver.save_catalogs(@catalog_tree)

    end # stop_parse_catalogs

    def start_parse_catalog

      return if @start_parse_catalogs != true

      @start_parse_catalog = true
      @catalog             = {}

    end # start_parse_catalog

    def stop_parse_catalog

      return if @start_parse_catalog != true

      @start_parse_catalog  = false

      @catalog[:parent_id]  = @catalog_parent_id[@catalog_level-1]
      @catalog[:dep_code]   = @catalog_dep_code

      @catalog_tree[@catalog_level] ||= []
      @catalog_tree[@catalog_level] << @catalog

    end # stop_parse_catalog

    def up_catalog_level
      @catalog_level += 1
    end # up_catalog_level

    def down_catalog_level
      @catalog_level  -= 1
    end # down_catalog_level

    def grub_catalog(attr_name)
      @catalog[attr_name] = @str if for_catalog?
    end # grub_catalog

    def for_catalog?
      @start_parse_catalog == true && parent_tag == "Группа"
    end # for_catalog?

=begin
    def start_catalogs
      @catalog_level += 1
      @catalogs.last['level'] = @catalog_level-1 if @catalog_level > 0
    end

    def start_catalog
      @catalogs << {}
    end

    def stop_catalogs
      if parent_tag == 'Классификатор'
        @catalogs.each do |c|
          save_catalog(c)
        end
      end
      @catalog_level -= 1
    end

    def stop_catalog
      return if @catalogs.last['level']
      @catalogs.last['level'] = @catalog_level
      if @catalog_level > 0
        possible_parents = @catalogs.select {|sel| sel['level'] == (@catalog_level - 1)}
        @catalogs.last['parent'] = possible_parents.last['id'] if possible_parents && possible_parents.last['id']
      elsif @catalog_level == 0
        @catalogs.last['parent'] = ''
      end
    end

    def start_parse_price
      @parse_price = true
    end # start_parse_price

    def stop_parse_price

      if !@price_name.blank? && !@price_id.blank?
        @price_types[@price_id] = @price_name
      end

      @price_name   = nil
      @price_id     = nil
      @parse_price  = false

    end # stop_parse_price

    def start_parse_item

      @start_parse_item = true
      @item = {}

    end # start_parse_item

    def stop_parse_item
      save_item(@item) if validate_1c_8(@item)

      @start_parse_item = false
      @item = {}

    end # start_parse_item

    def start_parse_item_price
      @start_parse_item_price = true
    end # start_parse_item_price

    def stop_parse_item_price

      if !@item_price.blank? && !@item_price_id.blank?

        case @price_types[@item_price_id]

          when "Опт" then
            @item["supplier_wholesale_price"] = @item_price

          when "Закупочная" then
            @item["supplier_purchasing_price"] = @item_price

        end # case

      end # if

      @item_price     = nil
      @item_price_id  = nil
      @item_discount  = nil
      @start_parse_item_price = false

    end # stop_parse_item_price
=end

    #
    # Validations
    #

    def validate_1c_8(attrs)

      return false if attrs.empty?

      if attrs['code_1c'].blank?
        @saver.log "[Errors 1C 8] Не найден идентификатор у товара: #{attrs['marking_of_goods']}"
        return false
      end

      # if attrs['department'].blank?
      #   @saver.log "[Errors 1C 8] Не найден отдел у товара: #{attrs['marking_of_goods']}"
      #   return false
      # end

      if attrs['name'].blank?
        @saver.log "[Errors 1C 8] Не найдено название у товара: #{attrs['marking_of_goods']}"
        return false
      end

      if attrs['marking_of_goods'].blank?
        @saver.log "[Errors 1C 8] Не найден артикул у товара: #{attrs['name']}"
        return false
      end

      if @validation_stage == 2
        if attrs['supplier_wholesale_price'].blank?
          @saver.log "[Errors 1C 8] Не найдена оптовая цена у товара: #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end

        if attrs['available'].blank?
          @saver.log "[Errors 1C 8] Не найдено количество товара: #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end
      end

      if @validation_stage == 1
        if attrs['catalog'].blank?
          @saver.log "[Errors 1C 8] Товар не привязан : #{attrs['marking_of_goods']} - #{attrs['name']}"
          return false
        end
      end

      true

    end # validate_1c_8

    def validate_1c_77_item(attrs)

      return false if attrs.empty?

      if attrs['id'].blank?
        @saver.log "[Errors 1C 7.7] Не найден идентификатор у товара: #{attrs['artikul']}"
        return false
      end

      if attrs['name'].blank?
        @saver.log "[Errors 1C 7.7] Не найдено название у товара: #{attrs['artikul']}"
        return false
      end

      if attrs['artikul'].blank?
        @saver.log "[Errors 1C 7.7] Не найден артикул у товара: #{attrs['name']}"
        return false
      end

      if attrs['price'].blank?
        @saver.log "[Errors 1C 7.7] Не найдена цена у товара: #{attrs['artikul']} - #{attrs['name']}"
        return false
      end

      if attrs['catalog'].blank?
        @saver.log "[Errors 1C 7.7] Товар: #{attrs['artikul']} не принадлежит ни одному каталогу"
        return false
      end

      if attrs['count'].blank?
        @saver.log "[Errors 1C 7.7] Неизвестное количество товара: #{attrs['artikul']}"
        return false
      end

      if attrs['unit'].blank?
        @saver.log "[Errors 1C 7.7] Неизвестная товарная единица у товара: #{attrs['artikul']}"
        return false
      end

      if attrs['in_pack'].blank?
        @saver.log "[Errors 1C 7.7] Неизвестное количество в упаковке товара: #{attrs['artikul']}"
        return false
      end

      true

    end # validate_1c_77_item

    def validate_1c_77_catalog(attrs)

      return false if attrs.empty?

      if attrs['name'].blank?
        @saver.log "[Errors 1C 7.7] Не найдено имя у каталога: #{attrs['id']}"
        return false
      end

      true

    end # validate_1c_77_catalog

  end # XmlParser

end # VoshodAvtoImport
