# encoding: utf-8
require 'rails/railtie'

module VoshodAvtoImport

  class Railtie < ::Rails::Railtie #:nodoc:

    config.after_initialize do

      Imp( ::VoshodAvtoImport::proc_name, ::VoshodAvtoImport::daemon_log ) do

        loop do

          ::VoshodAvtoImport.run
          ::GC.start
          sleep ::VoshodAvtoImport::wait

        end # loop

      end # Imp

    end # initializer

  end # Railtie

end # VoshodAvtoImport
