# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

Plugin.create(:sub_parts_image_flex) {
  UserConfig[:sub_parts_image_flex_max_height] ||= 300

  settings("インライン画像表示") {
    adjustment("画像の最大縦幅(px)", :sub_parts_image_flex_max_height, 0, 10000)
  }

  class Gdk::SubPartsImageFlex < Gdk::SubParts
    register

    def initialize(*args)
      super
      @pixbufs = []
      @rects = []

      urls = helper.message.entity.map { |t|
        case t[:slug]
        when :urls
          t[:expanded_url]
        when :media
          t[:media_url]
        else
          nil
        end
      }.compact

      unless urls.empty?
        Thread.new {
          urls.each { |url|
            _, loader, thread = Plugin.filtering(:openimg_pixbuf_from_display_url, url, nil, nil)
            if thread && thread.join(60) && loader.pixbuf
              @pixbufs << loader.pixbuf
            end
            @reseted_height = false
          }
          Reserver.new(1) {
            Delayer.new {
              helper.reset_height
            }
          }
        }
      end
    end

    # サブパーツを描画
    def render(context)
      @rects = @pixbufs.compact.map.with_index { |pixbuf, i|
        max_width = self.width / @pixbufs.length
        rect = Gdk::Rectangle.new(
          i * max_width, 0, max_width, UserConfig[:sub_parts_image_flex_max_height]
        )

        hscale = rect.height.to_f / pixbuf.height.to_f
        wscale = rect.width.to_f / pixbuf.width.to_f

        pixbuf =
          if rect.height < (pixbuf.height * wscale) # 縦にはみだす場合
            pixbuf.scale(pixbuf.width * hscale, pixbuf.height * hscale)
          else
            pixbuf.scale(pixbuf.width * wscale, pixbuf.height * wscale)
          end
        rect.width = pixbuf.width
        rect.height = pixbuf.height

        context.save {
          context.translate(rect.x, rect.y)
          context.set_source_pixbuf(pixbuf)
          context.paint
        }
        rect
      }
      unless @pixbufs.empty? || @reseted_height
        @reseted_height = true
        helper.reset_height
      end
    end

    def height
      if @rects.empty?
        0
      else
        @rects.map(&:height).max
      end
    end
  end
}
