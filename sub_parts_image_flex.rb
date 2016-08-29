# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

Plugin.create(:sub_parts_image_flex) {
  UserConfig[:sub_parts_image_flex_max_height] ||= 350

  settings("インライン画像表示") {
    adjustment("画像の最大縦幅(px)", :sub_parts_image_flex_max_height, 0, 10000)
  }

  class Gdk::SubPartsImageFlex < Gdk::SubParts
    regist

    def initialize(*args)
      super
      @pixbufs = []
      if helper.message
        # URLを解決
        urls = helper.message.entity
               .select { |entity| %i<urls media>.include? entity[:slug] }
               .map { |entity|
          case entity[:slug]
          when :urls
            entity[:expanded_url]
          when :media
            entity[:media_url]
          end
        }
        streams = urls.map { |url|
          Plugin.filtering(:openimg_raw_image_from_display_url, url, nil)
        }.select(&:last)
        # 画像を保存
        streams.each.with_index { |(_, stream), index|
          pixbuf = Gdk::PixbufLoader.open{ |loader|
            loader.write(stream.read)
            stream.close
          }.pixbuf
          @pixbufs[index] = pixbuf
        }
      end
    end

    # サブパーツを描画
    def render(context)
      @rects = @pixbufs.map.with_index { |pixbuf, i|
        max_width = self.width / @pixbufs.length
        rect = Gdk::Rectangle.new(
          i * max_width, 0, max_width, UserConfig[:sub_parts_image_flex_max_height])

        hscale = rect.height.to_f / pixbuf.height.to_f
        wscale = rect.width.to_f / pixbuf.width.to_f

        pixbuf =
          if rect.height < (pixbuf.height * wscale) then # 縦にはみだす場合
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
      if @rects.empty? then
        0
      else
        @rects.max_by { |x| x.height } .height
      end
    end
  end
}
