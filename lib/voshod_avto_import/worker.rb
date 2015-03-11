# encoding: utf-8
module VoshodAvtoImport

  # Сохранение данных (добавление новых, обновление сущестующих), полученных
  # при разборе xml-файла.
  class Worker

    def self.parse(file, parsers_map)
      new(file, parsers_map).parse
    end # self.parse

    def initialize(file, parsers_map)

      @file             = file
      @parsers_map      = parsers_map
      @file_name        = ::File.basename(@file)
      @dep_codes        = ::Set.new
      @updated_items    = []
      @updated_catalogs = []

    end # new

    def parse

      log "[#{::Time.now.strftime('%H:%M:%S %d-%m-%Y')}] Обработка файлов импорта ============================"

      unless @file && ::FileTest.exists?(@file)
        log "Файл не найден: #{@file}"
      else

        log "Файл: #{@file}\n"

        start = ::Time.now.to_f

        prepare_work
        work_with_file
        complete_work

        deps = @dep_codes.delete_if{ |el| el.nil? || el == 0 }

        departments = deps.inject([]) { |arr, el|
          arr << (::VoshodAvtoImport::DEPS[el] || { name: 'Неизвестно' })[:name]
        }

        if @partial_update
          log "[Частичное обновление данных] #{departments.join('. ')}."
        else
          log "[Полное обновление данных] #{departments.join('. ')}."
        end

        log "Товаров: "
        log "   добавлено: #{@items_ins}"
        log "   обновлено: #{@items_upd}"
        log "Каталогов: "
        log "   добавлено: #{@catalogs_ins}"
        log "   обновлено: #{@catalogs_upd}"
        log "Затрачено времени: #{ '%0.3f' % (::Time.now.to_f - start) } секунд."
        log ""

      end # if

      if @partial_update

        begin
          clb = ::VoshodAvtoImport.partial_update
          clb.call(departments, ::VoshodAvtoImport.dump_log) if clb.is_a?(::Proc)
        rescue => ex
          log ex.inspect
        end

      else

        begin
          clb = ::VoshodAvtoImport.full_update
          clb.call(departments, ::VoshodAvtoImport.dump_log) if clb.is_a?(::Proc)
        rescue => ex
          log ex.inspect
        end

      end

      self

    end # parse_file

    def save_catalog(rc)

      @dep_codes << rc[:dep_code]

      catalog = ::Catalog.where(raw: false, key_1c: rc[:key_1c]).first
      catalog ||= ::Catalog.new(raw: true, key_1c: rc[:key_1c])

      # Для корневых каталогов
      if rc[:key_1c_parent].nil?
        parent_id    = nil
      else

      # Обычные каталоги
        parent_id     = ::Catalog.where(raw: true,  key_1c: rc[:key_1c_parent]).first.try(:id)
        parent_id   ||= ::Catalog.where(raw: false, key_1c: rc[:key_1c_parent]).first.try(:id)

        if parent_id.nil?
          log "[Errors] Не найден родительский каталог: #{rc.inspect}"
          return
        end

      end # if

      catalog.pos             = rc[:pos] || 0
      catalog.name            = rc[:name]
      catalog.dep_code        = rc[:dep_code]
      catalog.key_1c_parent   = rc[:key_1c_parent]

      catalog.parent_id       = parent_id
      catalog.updated_at      = ::Time.now.utc

      new_record              = catalog.new_record?

      if catalog.with(safe: true).save

        @updated_catalogs << catalog.id

        if new_record
          @catalogs_ins += 1
        else
          @catalogs_upd += 1
        end

      else
        log "[Error] Не могу сохранить каталог: #{rc.inspect}"
      end

    end # save_catalog

    def save_item(rc)

      @dep_codes << rc[:dep_code]

      item  = ::Item.where(key_1c: rc[:key_1c]).limit(1).first
      item  ||= ::Item.new(raw: true,  key_1c: rc[:key_1c])

      if (price = rc[:price].try(:to_i) || 0) > 0
        item.price    = price
      end

      item.name       = ::VoshodAvtoImport::Util.xml_unescape(rc[:name])
      item.key_1c     = rc[:key_1c]
      item.count      = rc[:count]                      unless rc[:count].blank?
      item.mog        = rc[:mog]
      item.vendor_mog = rc[:mog_vendor]                 unless rc[:mog_vendor].blank?
      item.unit       = rc[:unit]
      item.catalog_1c = rc[:catalog_1c]                 unless rc[:catalog_1c].blank?
      item.department = rc[:dep_code]
      item.dep_key    = "#{rc[:dep_code]}-#{rc[:mog]}"
      item.vendor     = rc[:vendor]                     unless rc[:vendor].blank?
      item.updated_at = ::Time.now.utc

      new_record      = item.new_record?

      # Кросы доступны только для отдела Иномарки
      if [6].include?(rc[:dep_code]) && !rc[:crosses].blank?
        item.crosses  = parse_additional_info(rc[:crosses])
      end

      if item.save

        @updated_items << item.id

        if new_record
          @items_ins += 1
        else
          @items_upd += 1
        end

      else
        log "[#{(new_record ? 'INSERT' : 'UPDATE')}] (#{rc[:key_1c]}: #{rc[:mog]}) #{item.errors.inspect}"
      end

    end # save_item

    def save_item_extend(rc)

      @dep_codes << rc[:dep_code]

      item   = ::Item.where(key_1c: rc[:key_1c]).first
      item   ||= ::Item.new(raw: true,  key_1c: rc[:key_1c])

      if (price = rc[:price].try(:to_i) || 0) > 0
        item.price  = price
      end

      item.count      = rc[:count] || 0
      item.name       = rc[:name]
      item.mog        = rc[:mog]
      item.department = rc[:dep_code]
      item.dep_key    = "#{rc[:dep_code]}-#{rc[:mog]}"
      item.updated_at = ::Time.now.utc

      new_record      = item.new_record?

      if item.save

        @updated_items << item.id

        if new_record
          @items_ins += 1
        else
          @items_upd += 1
        end

      else
        log "[#{(new_record ? 'INSERT' : 'UPDATE')}] (#{rc[:key_1c]}: #{rc[:mog]}) #{item.errors.inspect}"
      end

    end # save_item_extend

    def set_partial(val)
      @partial_update = (val == true)
    end # set_partial

    def set_price_processing(val)
      @price_processing = (val == true)
    end # set_price_processing

    def log(msg)
      ::VoshodAvtoImport.log(msg)
    end # log

    private

    def prepare_work

      @partial_update   = true
      @items_ins        = 0
      @items_upd        = 0
      @catalogs_ins     = 0
      @catalogs_upd     = 0
      @price_processing = false

    end # prepare_work

    def complete_work

      # Завершаем работу, если обрабатывали цены
      return if @price_processing

      # Удаляем товары без каталогов
      ::Item.with(safe: true).where(:catalog_1c => nil).delete_all

      # Удаляем товары без отделов
      ::Item.with(safe: true).where(:department => nil).delete_all

      deps = @dep_codes.delete_if{ |el| el.nil? }.to_a

      # Если обновление полное то, удаляем прежние данные:
      # -- каталоги
      # -- товары
      unless @partial_update

        # Обновляем все кроссы при полном обновлении
        ::ItemCross.reload_all if deps.include?(6)

        # Удаляем каталоги
        ::Catalog.
          with(safe: true).
          where(raw: false, :dep_code.in => (deps - [0]), :id.nin => @updated_catalogs).
          delete_all

        ::Item.
          with(safe: true).
          where(raw: false, :department.in => deps, :id.nin => @updated_items).each do |item|

            item.remove_from_sphinx
            item.delete

        end

        # Закрываем обработку каталогов и товаров
        ::Catalog.
          with(safe: true).
          where(:dep_code.in => deps).
          update_all({ raw: false })

        ::Item.
          with(safe: true).
          where(:department.in => deps).each do |item|

            item.set(:raw, false)
            item.update_sphinx

        end

        @catalogs_ins  = ::Catalog.where(:dep_code.in => deps).count
        @catalogs_upd  = 0

      else

        # Закрываем обработку каталогов и товаров
        ::Catalog.
          with(safe: true).
          where(raw: true, :dep_code.in => deps).
          update_all({ raw: false })

        ::Item.
          with(safe: true).
          where(raw: true, :department.in => deps).each do |item|

            item.set(:raw, false)
            item.update_sphinx

        end

      end # unless

      @updated_items    = []
      @updated_catalogs = []

    end # complete_work

    def work_with_file

      pt      = ::VoshodAvtoImport::XmlParser.new(self, @parsers_map)
      parser  = ::Nokogiri::XML::SAX::Parser.new(pt)
      parser.parse_file(@file)

      ::VoshodAvtoImport.backup_file_to_dir(@file)

    end # work_with_file

    def parse_additional_info(info)

      (info || "").
        split(/\s\/\s|\n|\r|\t|\,|\;/).
        map { |el| el.clean_whitespaces }.
        delete_if { |el| el.blank? || el.length > 40 }.
        uniq

    end # parse_additional_info

  end # Worker

end # VoshodAvtoImport
