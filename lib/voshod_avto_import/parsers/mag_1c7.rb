# encoding: utf-8
module VoshodAvtoImport

  class Mag1c7Parser < ::VoshodAvtoImport::BaseParser

    def initialize(saver)

      super(saver)

      @level              = 0
      @tags               = {}
      @catalogs_item_map  = {}

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

      case name

        # 1C 7.7
        when 'doc' then
          stop_parse_catalogs
          save_items

      end # case

    end # end_element

    private

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

    def reset_datas!

      @catalog_level        = 0
      @catalog_parent_id    = {}
      @catalog              = {}
      @catalogs_array       = []

    end # reset_datas!

    def tag_doc(attrs)

      @catalog_dep_code = 7
      @catalog          = {

        dep_code: @catalog_dep_code,
        name:     'Магнитогорск',
        id:       "dep",
        pos:      6

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

    def save_items

      @items ||= []

      @items.each do |item|
        @saver.save_item(item)
      end

      @items = []

    end # save_items

  end # Mag1c7Parser

end # VoshodAvtoImport
