# encoding: UTF-8
module VoshodAvtoImport

  # Сохранение данных (добавление новых, обновление сущестующих), полученных
  # при разборе xml-файла.
  class Worker
    attr_writer :partial
    def initialize(file, manager)

      @file         = file
      @ins, @upd    = 0, 0
      @cins, @cupd  = 0, 0
      @file_name    = ::File.basename(@file)
      @manager      = manager
      @items_not_deleted    = []
      @catalogs_not_deleted = []
      @partial      = false
    end # new

    def parse

      log "[#{Time.now.strftime('%H:%M:%S %d-%m-%Y')}] Обработка файлов импорта ============================"

      unless @file && ::FileTest.exists?(@file)
        log "Файл не найден: #{@file}"
      else

        log "Файл: #{@file}\n"

        start = Time.now.to_f

        work_with_file

        log "Добавлено товаров: #{@ins}"
        log "Обновлено товаров: #{@upd}"
        log "Добавлено каталогов #{@cins}:"
        log "Обновлено каталогов #{@cupd}:"
        log "Затрачено времени: #{ '%0.3f' % (Time.now.to_f - start) } секунд."
        log ""
        @manager.ins += @ins
        @manager.upd += @upd

        start = Time.now.to_f

        begin

          # если содержит только изменения, то не делаем пометку на удаление
          unless @partial
            cats = Catalog.where(:_id.nin => @catalogs_not_deleted, :dep_code => @root_catalog.dep_code)
            items = Item.where(:_id.nin => @items_not_deleted, :department => @root_catalog.dep_code)

            log "Помечено каталогов на удаление: #{cats.count}"
            log "Помечено товаров на удаление: #{items.count}"

            cats.update_all(:deleted => true)
            items.update_all(:deleted => true)
            items.each(&:remove_from_sphinx)
          end

        end

        log "Затрачено времени на 'удаление': #{ '%0.3f' % (Time.now.to_f - start) } секунд."
        log ""
        log ""

      end

      self

    end # parse_file


    def save_doc(
      department, 
      datetime # Time object
      )

      dep = Catalog::DEPS[Catalog::REV_DEPS[department]]
      return unless dep

      dep_code = Catalog::REV_DEPS[department]

      if (@root_catalog = ::Catalog.where(:dep_code => dep_code).limit(1).to_a[0])
        @root_catalog.name        = dep[:name]
        @root_catalog.updated_at  = datetime
        @root_catalog.pos         = dep[:pos]
        @root_catalog.deleted     = false

        if @root_catalog.save
          @cupd +=1
          true
        else
          false
        end

      else
        @root_catalog = ::Catalog.new
        @root_catalog.name        = dep[:name]
        @root_catalog.updated_at  = datetime
        @root_catalog.pos         = dep[:pos]
        @root_catalog.deleted     = false
        @root_catalog.dep_code    = dep_code

        if @root_catalog.save
          @cins +=1
          true
        else
          false
        end
      end

      @root_catalog.with({safe:true}).save
      @catalogs_not_deleted << @root_catalog._id

    end # save_doc

    def save_catalog(
      id,
      name,
      parent
      )

      internal_id = "#{@root_catalog.dep_code}-#{id}"
      internal_parent = "#{@root_catalog.dep_code}-#{parent}"

      parent_node = Catalog.where(:key_1c => internal_parent).first

      catalog = nil

      if ( catalog = ::Catalog.where(:key_1c => internal_id).limit(1).to_a[0])
        catalog.name        = name.xml_unescape
        #catalog.updated_at  = @root_catalog.updated_at
        catalog.deleted     = false
        if catalog.save(validate: false)
          @cupd +=1
          true
        else
          false
        end
      else
        catalog             = ::Catalog.new
        catalog.key_1c      = internal_id
        catalog.name        = name.xml_unescape
        #catalog.updated_at  = @root_catalog.updated_at
        catalog.deleted     = false

        if catalog.save(validate: false)
          @cins +=1
          true
        else
          false
        end
      end

      @catalogs_not_deleted << catalog._id

      begin
        if parent_node.nil? || (parent_node.is_a?(Array) && parent_node.empty?)
          catalog.move_to_child_of(@root_catalog)
        else
          catalog.move_to_child_of(parent_node)

        end
      rescue => e
        log "Exception: #{e.message}"
        log "internal_parent = #{internal_parent.inspect}"
        log "original parent = #{catalog.parent.inspect}"
        log "Moving #{[catalog.name,catalog.key_1c,catalog.id].inspect} to #{[@root_catalog.name,@root_catalog.key_1c,@root_catalog.id].inspect}" if parent_node.nil?
        log "Moving #{[catalog.name,catalog.key_1c,catalog.id].inspect} to #{[parent_node.name,parent_node.key_1c,parent_node.id].inspect}" unless parent_node.nil?
      end

    end # save_doc

    def save_item(
      id,
      name,
      artikul,
      vendor_artikul,
      price,
      count,
      unit,
      in_pack,
      catalog,
      vendor,
      additional_info
      )

      internal_id = "#{@root_catalog.dep_code}-#{id}"
      catalog_id = catalogs_cache("#{@root_catalog.dep_code}-#{catalog}")

      if (item = ::Item.where(:key_1c => internal_id).limit(1).first)

        item.name       = name.xml_unescape
        item.key_1c     = internal_id
        item.price      = price                     unless price.blank?
        item.count      = count                     unless count.blank?
        item.mog        = artikul
        item.vendor_mog = vendor_artikul            unless vendor_artikul.blank?
        item.vendor_mog_normalized = vendor_artikul.normalize_artikul unless vendor_artikul.blank?
        item.unit       = unit
        item.in_pack    = in_pack > 0 ? in_pack : 1 
        item.catalog_id = catalog_id                unless catalog.blank?
        item.department = @root_catalog.dep_code
        item.dep_key    = "#{@root_catalog.dep_code}-#{artikul}"
        item.deleted    = false
        item.vendor     = vendor
        item.additional_info = parse_additional_info(additional_info)

        item.crc32_cur = Zlib.crc32(item.additional_info.join(',')) if item.additional_info

        if item.save
          @upd +=1
          true
        else
          log "[UPDATE] (#{id}-#{key_1c}: #{artikul}) #{item.errors.inspect}"
          false
        end

      else
        item = ::Item.new
        item.key_1c     = internal_id
        item.name       = name.xml_unescape
        item.price      = price || 0
        item.count      = count || 0
        item.mog        = artikul
        item.vendor_mog = vendor_artikul          unless vendor_artikul.blank?
        item.vendor_mog_normalized = vendor_artikul.normalize_artikul unless vendor_artikul.blank?
        item.unit       = unit
        item.in_pack    = in_pack > 0 ? in_pack : 1
        item.catalog_id = catalog_id  unless catalog.blank?
        item.department = @root_catalog.dep_code
        item.dep_key    = "#{@root_catalog.dep_code}-#{artikul}"
        item.vendor     = vendor || nil
        item.additional_info = parse_additional_info(additional_info)

        item.crc32_cur = Zlib.crc32(item.additional_info.join(',')) if item.additional_info

        if item.save
          @ins+=1
          true
        else
          log "[INSERT] (#{id}-#{key_1c}: #{artikul}) #{item.errors.inspect}"
          false
        end
      end

      @items_not_deleted << item._id
    end # save_item

    def log(msg)
      @manager.log(msg)
    end # log

    private

    def work_with_file

      pt = ::VoshodAvtoImport::XmlParser.new(self)

      parser = ::Nokogiri::XML::SAX::Parser.new(pt)
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

    def catalogs_cache(key_1c)
      @catalogs_cache ||= {}

      if id = @catalogs_cache[key_1c]
        id
      else
        id = ::Catalog.where(:key_1c => key_1c).first.try(:id)
        @catalogs_cache[key_1c] = id
        id
      end # if
    end # catalogs_cache

    def parse_additional_info(info)
      info.split(/ \/ /).map{|el| el.strip.normalize_artikul} if info
    end

  end # Worker

end # VoshodAvtoImport
