# coding: utf-8
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
      @photos = helper.message.entity.select { |t| t[:type] == "photo" }.compact.map { |t|
        t[:open]
      }.compact
      @pixbufs = []
    end

    def render(context)
      @photos.each.with_index { |photo, index|
        w = self.width / @photos.length
        h = UserConfig[:mikutter_sub_parts_image_flex_max_height]
        if pix = photo.pixbuf(width: w, height: h)
          @pixbufs[index] = pix
          unless @reseted
            @reseted = true
            helper.reset_height
          end
        else
          photo.load_pixbuf(width: w, height: h) { |pixbuf|
            @pixbufs[index] = pixbuf
            helper.reset_height
            helper.on_modify
          }
        end
      }
      @pixbufs.compact.each.with_index { |pixbuf, index|
        context.save {
          context.translate(index * (self.width / @photos.length), 0)
          context.set_source_pixbuf(pixbuf)
          context.paint
        }
      }
    end

    def height
      if @pixbufs.empty?
        0
      else
        [@pixbufs.compact.map(&:height).max,
         UserConfig[:mikutter_sub_parts_image_flex_max_height]
        ].min
      end
    end
  end
}
