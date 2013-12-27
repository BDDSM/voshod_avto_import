# encoding: UTF-8
module VoshodAvtoImport

  # Сохранение данных (добавление новых, обновление сущестующих), полученных
  # при разборе xml-файла.
  class Worker

    def initialize(file, manager)

      @file         = file
      @file_name    = ::File.basename(@file)
      @manager      = manager
      @dep_codes    = {}

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

        log "Товаров: "
        log "   добавлено: #{@items_ins}"
        log "   обновлено: #{@items_upd}"
        log "Каталогов: "
        log "   добавлено: #{@catalogs_ins}"
        log "   обновлено: #{@catalogs_upd}"
        log "Затрачено времени: #{ '%0.3f' % (::Time.now.to_f - start) } секунд."
        log ""

      end # if

      self

    end # parse_file

    def save_catalog(rc)

      key_1c = "#{rc[:dep_code]}-#{rc[:id]}"
      @dep_codes[rc[:dep_code]] = true

      if (catalog = ::Catalog.where(raw: true, key_1c: key_1c).limit(1).first).nil?

        catalog = ::Catalog.new

        if rc[:parent_id].blank?
          parent_id = nil
        else

          rc_parent_id  = "#{rc[:dep_code]}-#{rc[:parent_id]}"
          parent_id     = ::Catalog.where(raw: true, key_1c: rc_parent_id).limit(1).first.try(:id)

          if parent_id.nil?
            log "[Errors] Не найден родительский каталог: #{rc.inspect}"
            return
          end

        end

        catalog.parent_id     = parent_id
        catalog.key_1c_parent = rc_parent_id
        catalog.key_1c        = key_1c
        catalog.raw           = true

      end # if

      catalog.pos             = rc[:pos] || 0
      catalog.name            = rc[:name]
      catalog.dep_code        = rc[:dep_code]
      new_record              = catalog.new_record?

      if catalog.with(safe: true).save

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

      key_1c      = "#{rc[:dep_code]}-#{rc[:id]}"
      catalog_1c  = "#{rc[:dep_code]}-#{rc[:catalog_id]}"

      @dep_codes[rc[:dep_code]] = true

      item            = ::Item.where(:key_1c => key_1c).limit(1).first
      item            ||= ::Item.new

      item.raw        = item.new_record?
      item.name       = rc[:name].xml_unescape
      item.key_1c     = key_1c
      item.price      = rc[:price]                     unless rc[:price].blank?
      item.count      = rc[:count]                     unless rc[:count].blank?
      item.mog        = rc[:mog]
      item.vendor_mog = rc[:mog_vendor]                unless rc[:mog_vendor].blank?
      item.unit       = rc[:unit]
      item.catalog_1c = catalog_1c
      item.department = rc[:dep_code]
      item.dep_key    = "#{rc[:dep_code]}-#{rc[:mog]}"
      item.vendor     = rc[:vendor]                   unless rc[:vendor].blank?

      item.additional_info = parse_additional_info(rc[:additional_info])  unless rc[:additional_info].blank?
      item.crc32_cur  = Zlib.crc32(item.additional_info.join(','))        if item.additional_info

#      item.in_pack    = rc[:in_pack] > 0 ? in_pack : 1
#      item.vendor_mog_normalized = vendor_artikul.normalize_artikul unless vendor_artikul.blank?

      new_record      = item.new_record?

      if item.save

        if new_record
          @items_ins += 1
        else
          @items_upd += 1
        end

      else
        log "[#{(new_record ? 'INSERT' : 'UPDATE')}] (#{key_1c}: #{rc[:mog]}) #{item.errors.inspect}"
      end

    end # save_item

    def save_item_extend(id, rc)

      key_1c = "#{rc[:dep_code]}-#{id}"
      @dep_codes[rc[:dep_code]] = true

      item   = ::Item.where(:key_1c => key_1c).limit(1).first
      item   ||= ::Item.new

      item.key_1c = key_1c
      item.price  = rc["Опт"]   || 0
      item.count  = rc[:count]  || 0
      new_record  = item.new_record?

      if item.save

        if new_record
          @items_ins += 1
        else
          @items_upd += 1
        end

      else
        log "[#{(new_record ? 'INSERT' : 'UPDATE')}] (#{key_1c}: #{rc[:mog]}) #{item.errors.inspect}"
      end

    end # save_item_extend

    def set_partial(val)
      @partial_update = (val == true)
    end # set_partial

    def set_price_processing(val)
      @price_processing = (val == true)
    end # set_price_processing

    def log(msg)
      @manager.log(msg)
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

      deps = @dep_codes.keys

      # Если обновление полное то, удаляем прежние данные:
      # -- каталоги
      # -- товары
      unless @partial_update

        # Удаляем каталоги
        ::Catalog.
          with(safe: true).
          where(raw: false, :dep_code.in => deps).
          delete_all

        ::Item.
          with(safe: true).
          where(raw: false, :department.in => deps).each do |item|

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

        @items_ins        = ::Item.where(:department.in => deps).count
        @items_upd        = 0
        @catalogs_ins     = ::Catalog.where(:dep_code.in => deps).count
        @catalogs_upd     = 0

      else

        # Удаляем добавленные каталоги
        ::Catalog.
          with(safe: true).
          where(raw: true, :dep_code.in => deps).
          delete_all

        # Удаляем добавленные товары
        ::Item.
          with(safe: true).
          where(raw: true, :department.in => deps).
          delete_all

        @items_ins        = 0
        @catalogs_ins     = 0

      end # unless

    end # complete_work

    def work_with_file

      pt      = ::VoshodAvtoImport::XmlParser.new(self)
      parser  = ::Nokogiri::XML::SAX::Parser.new(pt)
      parser.parse_file(@file)

      begin

        if ::VoshodAvtoImport::backup_dir && ::FileTest.directory?(::VoshodAvtoImport::backup_dir)
          ::FileUtils.mv(@file, "#{::VoshodAvtoImport.backup_dir}/#{Time.now.strftime("%Y%m%d_%H%M")}_#{@file_name}")
        end

      rescue SystemCallError
        log "Не могу переместить файл `#{@file_name}` в `#{::VoshodAvtoImport.backup_dir}`"
      ensure
        ::FileUtils.rm_rf(@file)
      end

    end # work_with_file

    def parse_additional_info(info)
      (info || "").split(/\s\/\s/).map{ |el| el.strip.normalize_artikul }
    end # parse_additional_info

  end # Worker

end # VoshodAvtoImport
