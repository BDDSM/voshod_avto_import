# encoding: utf-8
module VoshodAvtoImport

  # Предварительная обработка выгрузки (распаковка архивов).
  # Запуск обработчика. Отправка отчетов.
  class Manager

    def self.run
      new.run
    end # self.run

    def initialize
    end # new

    def run

      @has_files = false

      ::VoshodAvtoImport.clear_log

      extract_zip_files
      processing

      yield if @has_files && block_given?

      ::VoshodAvtoImport.clear_log

    end # run

    def log(msg = "")
      ::VoshodAvtoImport.log(msg)
    end # log

    private

    def import_dirs
      @import_dirs ||= (::VoshodAvtoImport::import_map || {}).keys
    end # import_dirs

    def import_map
      @import_map ||= (::VoshodAvtoImport::import_map || {})
    end # import_map

    def processing

      return self if import_map.empty?

      start = ::Time.now.to_f

      import_map.each do |dir, parsers_map|

        files = ::Dir.glob( ::File.join(dir, "**", "*.xml") )
        next unless files && files.size > 0

        @has_files = true

        # Сортируем по дате последнего доступа по-возрастанию
        files.sort{ |a, b| ::File.new(a).mtime <=> ::File.new(b).atime }.each do |xml_file|
          ::VoshodAvtoImport::Worker.parse(xml_file, parsers_map)
        end # each

      end # each

      log "На импорт всех файлов затрачено времени: #{ '%0.3f' % (::Time.now.to_f - start) } секунд."
      log ""

      self

    end # processing

    # Ищем и распаковываем все zip-архивы, после - удаляем
    def extract_zip_files

      import_dirs.each do |dir|

        files = ::Dir.glob( ::File.join(dir, "**", "*.zip") )
        next unless files && files.size > 0

        i = 0
        files.each do |zip|

          i+= 1
          begin

            ::Zip::File.open(zip) { |zip_file|

              zip_file.each { |f|

                # Создаем дополнительную вложенность т.к. 1С 8 выгружает всегда одни и теже
                # навания файлов, и если таких выгрузок будет много, то при распковке файлы
                # будут перезатираться

                f_path = ::File.join(
                  dir,
                  "#{i}",
                  f.file? ? "#{rand}-#{::Time.now.to_f}-#{f.name}" : f.name
                )

                ::FileUtils.rm_rf f_path if ::File.exist?(f_path)
                ::FileUtils.mkdir_p(::File.dirname(f_path))

                zip_file.extract(f, f_path)

              } # each

            } # open

            ::FileUtils.rm_rf(zip)

          rescue
          end

        end # Dir.glob

      end # each

      self

    end # extract_zip_files

  end # Manager

end # VoshodAvtoImport
