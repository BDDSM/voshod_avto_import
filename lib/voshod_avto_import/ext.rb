# encoding: utf-8
module VoshodAvtoImport

  module StringExt

    def utf8

      self.force_encoding(::Encoding::UTF_8) if self.respond_to?(:force_encoding)
      self

    end # utf8

    def escape

      self.
        gsub(/'/, "\\\\'").
        gsub(/"/, '\\\\"').
        gsub(/\n/, "\\n").
        gsub(/\r/, "\\r")

    end # escape

  end # StringExt

  module NilExt

    def utf8
      self
    end # utf8

  end # NilExt

end # VoshodAvtoImport

class String
  include ::VoshodAvtoImport::StringExt
end # String

class NilClass
  include ::VoshodAvtoImport::NilExt
end
