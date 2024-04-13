# encoding: utf-8

require 'carrierwave/orm/activerecord'

module CarrierWave
  module ActiveRecord
    module Serializable
      def serialized_uploaders
        @serialized_uploaders ||= read_from_superclass? ? superclass.serialized_uploaders.dup : {}
      end

      def serialized_uploader?(column)
        serialized_uploaders.key?(column)
      end

      ##
      # See +CarrierWave::Mount#mount_uploader+ for documentation
      #
      def mount_uploader(column, uploader = nil, options = {}, &block)
        super

        serialize_to = options.delete :serialize_to
        if serialize_to
          serialization_column = options[:mount_on] || column
          serialized_uploaders[serialization_column] = serialize_to
          class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{serialization_column}_will_change!
              #{serialize_to}_will_change!
              @#{serialization_column}_changed = true
            end

            def #{serialization_column}_changed?
              @#{serialization_column}_changed
            end
          RUBY
        end

        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def write_uploader(column, identifier)
            if self.class.serialized_uploader?(column)
              serialized_field_name = self.class.serialized_uploaders[column].to_s

              if serialized_field = self.send(serialized_field_name)
                # 直接將檔案識別符(identifier)寫入序列化欄位，而不對其進行修改
                serialized_field[column.to_s] = identifier
              else
                # 如果序列化欄位尚未初始化，則初始化為空的 Hash，然後再寫入檔案識別符
                self.send("#{serialized_field_name}=", { column.to_s => identifier })
              end
            else
              # 如果不是序列化的檔案，則直接將檔案識別符(identifier)寫入模型的欄位中
              write_attribute(column, identifier)
            end
          end

          def read_uploader(column)
            if self.class.serialized_uploader?(column)
              serialized_field = self.send self.class.serialized_uploaders[column]
              serialized_field ? serialized_field[column.to_s] : nil
            else
              read_attribute(column)
            end
          end
        RUBY

      end

      private

      def read_from_superclass?
        superclass != ::ActiveRecord::Base && superclass.respond_to?(:serialized_uploaders)
      end
    end
  end
end
