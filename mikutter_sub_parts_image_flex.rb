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
      @photos = Plugin[:"score"].score_of(helper.message).select { |model|
        model.is_a?(Plugin::Score::HyperLinkNote)
      }.map{ |model|
        Plugin.filtering(:photo_filter, model.uri, []).last
      }.flatten.compact
      @reset_height_need = false
      @photos.each { |photo|
        photo.download_pixbuf(width: self.width,
                              height: self.max_height).next { |pixbuf|
          @reset_height_need = true
          helper.on_modify
        }.trap {
          Delayer.new {
            @photos.delete(photo)
          }
        }
      }
    end

    def render(context)
      old_height = self.height
      @pixbufs = @photos.map.with_index { |photo, index|
        pixbuf = photo.pixbuf(width: self.width, height: self.max_height)
        next nil unless pixbuf
        max_width = self.width / @photos.length
        rect = Gdk::Rectangle.new(index * max_width, 0, max_width, self.max_height)
        hscale = rect.height.to_f / pixbuf.height.to_f
        wscale = rect.width.to_f / pixbuf.width.to_f
        if rect.height < (pixbuf.height * wscale) # 縦にはみだす場合
          pixbuf.scale(pixbuf.width * hscale, pixbuf.height * hscale)
        else
          pixbuf.scale(pixbuf.width * wscale, pixbuf.height * wscale)
        end
      }.compact
      @pixbufs.each.with_index { |pixbuf, index|
        context.save {
          context.translate(index * (self.width / @pixbufs.length), 0)
          context.set_source_pixbuf(pixbuf)
          context.paint
        }
      }
      if @reset_height_need && old_height != self.height
        @reset_height_need = false
        helper.reset_height
      end
    end

    def height
      if @pixbufs.empty?
        0
      else
        [@pixbufs.map(&:height).max, self.max_height].min
      end
    end

    def max_height
      UserConfig[:mikutter_sub_parts_image_flex_max_height]
    end
  end
}
