# encoding: utf-8
class ImportController < ApplicationController

  unloadable

  before_filter :auth
  skip_before_filter :verify_authenticity_token, :only => [:save_file, :save_file_mag]

  def index

    case params[:mode]
      when 'checkauth'
        render(text: "success\nimport_1c\n#{rand(9999)}", layout: false) and return
      when 'init'
        render(text: "zip=yes\nfile_limit=99999999999999999", layout: false) and return
      when 'import'
        render(text: "success", layout: false) and return
      else
        render(text: "failure", layout: false) and return
    end

  end # index

  def save_file

    file_path = ::File.join('/home/vavtoimport', "#{rand}-#{::Time.now.to_f}.zip")
    ::File.open(file_path, 'wb') do |f|
      f.write request.body.read
    end

    render(text: "success", layout: false) and return

  end # save_file

  def save_file_mag

    file_path = ::File.join('/home/vavtoimportmag', "#{rand}-#{::Time.now.to_f}.zip")
    ::File.open(file_path, 'wb') do |f|
      f.write request.body.read
    end

    render(text: "success", layout: false) and return

  end # save_file_mag

  private

  def auth

    authenticate_or_request_with_http_basic do |login, password|
      (login == ::VoshodAvtoImport::login && password == ::VoshodAvtoImport::password)
    end

  end # auth

end # ImportController
