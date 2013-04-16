require 'rails/railtie'

module VoshodAvtoImport

  class Railtie < ::Rails::Railtie #:nodoc:

    config.after_initialize do

      Imp( ::VoshodAvtoImport::proc_name, ::VoshodAvtoImport::daemon_log ) do

        loop do

          ::VoshodAvtoImport::Manager.run
          sleep ::VoshodAvtoImport::wait

        end # loop

      end # Imp

      if !defined?(::IRB) && !defined?(::Rake) && ::Rails.env.to_s == "production"
        Imp(::VoshodAvtoImport::proc_name).start
      end # if

    end # initializer

  end # Railtie

end # VoshodAvtoImport
