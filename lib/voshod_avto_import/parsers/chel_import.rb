# encoding: utf-8
module VoshodAvtoImport

  class ChelImportParser < ::VoshodAvtoImport::BaseParser

    def initialize(saver)

      super(saver)

    end # initialize

    def start_element(name, attrs = [])

    end # start_element

    def end_element(name)
    end # end_element

  end # ChelImportParser

end # VoshodAvtoImport
