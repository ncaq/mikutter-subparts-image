# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

Plugin.create(:mikutter_sub_parts_image_flex) {
  UserConfig[:mikutter_sub_parts_image_flex_max_height] ||= 300

  settings("インライン画像表示") {
    adjustment("画像の最大縦幅(px)", :mikutter_sub_parts_image_flex_max_height, 0, 10000)
  }

  class Gdk::MikutterSubPartsImageFlex < Gdk::SubParts
    register

    def initialize(*args)
      super
      @height = UserConfig[:mikutter_sub_parts_image_flex_max_height]
      @photos = helper.message.entity.select { |t|
        t[:type] == "photo"
      }.compact.map { |t|
        t[:open]
      }.compact
    end

    def render(context)
      pixbufs = @photos.map { |photo|
        photo.load_pixbuf(width: self.width / @photos.length,
                          height: UserConfig[:mikutter_sub_parts_image_flex_max_height]) {
          helper.on_modify
        }
      }
      pixbufs.each.with_index { |pixbuf, index|
        context.save {
          context.translate(index * (self.width / pixbufs.length), 0)
          context.set_source_pixbuf(pixbuf)
          context.paint
        }
      }
      @height = pixbufs.map(&:height).max
      unless @reseted_height
        helper.reset_height
        @reseted_height = true
      end
    end

    def height
      if @photos.empty?
        0
      else
        @height
      end
    end
  end
}
