# encoding: utf-8
module VoshodAvtoImport

  class Ask1c7Parser < ::VoshodAvtoImport::BaseParser

    def initialize(saver)

      super(saver)

      @level              = 0
      @tags               = {}
      @catalogs_item_map  = {}
      @catalog_dep_code   = 1

    end # initialize

    def start_element(name, attrs = [])

      super(name, attrs)

      attrs  = ::Hash[attrs]

      @level += 1
      @tags[@level] = name

      case name

        when 'doc'      then
          start_parse_catalogs
          tag_doc(attrs)

        when 'catalog'  then
          tag_catalog(attrs)

        when 'item'     then
          tag_item(attrs)

      end # case

    end # start_element

    def end_element(name)
      @level -= 1
    end # end_element

    def end_document

      stop_parse_catalogs
      save_items

    end # end_document

    private

    def start_parse_catalogs

      return if @start_parse_catalogs == true

      @start_parse_catalogs = true
      reset_datas!

    end # start_parse_catalogs

    def stop_parse_catalogs

      return if @start_parse_catalogs != true

      @start_parse_catalogs = false

      @catalogs_array.each do |ct|
        @saver.save_catalog(ct)
      end

      reset_datas!

    end # stop_parse_catalogs

    def reset_datas!

      @catalog_level        = 0
      @catalog_parent_id    = {}
      @catalog              = {}
      @catalogs_array       = []

    end # reset_datas!

    def tag_doc(attrs)

      @catalogs_array << {

        key_1c:         "chel",
        key_1c_parent:  nil,
        dep_code:       0,
        name:           "Челябинск",
        pos:            2

      }

      @catalogs_array << {

        key_1c:         "#{@catalog_dep_code}-aks",
        key_1c_parent:  'chel',
        dep_code:       @catalog_dep_code,
        name:           'Аксессуары и электроника',
        pos:            0

      }

      @saver.set_partial(false)

    end # tag_doc

    def tag_catalog(attrs)

      @catalog  = {

        key_1c:   "#{@catalog_dep_code}-#{attrs['id'].squish}",
        dep_code: @catalog_dep_code,
        name:     attrs['name'].squish,

      }

      if (parent_id = attrs['parent'].squish).blank?
        @catalog[:key_1c_parent] = "#{@catalog_dep_code}-aks"
      else
        @catalog[:key_1c_parent] = "#{@catalog_dep_code}-#{parent_id}"
      end

      @catalogs_item_map[@catalog[:id]] = @catalog[:dep_code]
      @catalogs_array << @catalog if catalog_valid?

    end # tag_catalog

    def tag_item(attrs)

      @item = {

        dep_code:   @catalog[:dep_code],
        name:       attrs["name"].try(:squish),
        price:      attrs["price"].try(:squish),
        count:      attrs["count"].try(:to_i) || 0,
        mog:        attrs["artikul"].try(:squish),
        mog_vendor: attrs["vendor_artikul"].try(:squish),
        unit:       attrs["unit"].try(:squish)

      }

      unless (item_id = attrs['id'].squish).blank?
        @item[:key_1c] = "#{@catalog_dep_code}-#{item_id}"
      end

      unless (catalog_id = attrs['catalog'].squish).blank?
        @item[:catalog_1c] = "#{@catalog_dep_code}-#{catalog_id}"
      end

      (@items ||= []) << @item if item_valid?

    end # tag_item

    def save_items

      @items ||= []

      @items.each do |item|
        @saver.save_item(item)
      end

      @items = []

    end # save_items

  end # Ask1c7Parser

end # VoshodAvtoImport
