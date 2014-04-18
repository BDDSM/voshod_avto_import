# encoding: utf-8
module VoshodAvtoImport

  class EkbImportParser < ::VoshodAvtoImport::BaseParser

    def initialize(saver)

      super(saver)

    end # initialize

    def start_element(name, attrs = [])

    end # start_element

    def end_element(name)
    end # end_element

  end # EkbImportParser

end # VoshodAvtoImport
