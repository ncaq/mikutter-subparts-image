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
      @pixels = []

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
          @pixels[index] = pixbuf
        }
      end
    end

    # サブパーツを描画
    def render(context)
      @pixels.map!.with_index { |icon, i|
        max_width = self.width / @pixels.length
        rect = Gdk::Rectangle.new(
          i * max_width, 0, max_width, UserConfig[:sub_parts_image_flex_max_height])

        hscale = rect.height.to_f / icon.height
        wscale = rect.width.to_f / icon.width

        if rect.height < (icon.height * wscale) then # 横に拡大した時,縦にはみだす場合
          icon = icon.scale(icon.width * hscale, icon.height * hscale)
        else
          icon = icon.scale(icon.width * wscale, icon.height * wscale)
        end

        context.save {
          context.translate(rect.x, rect.y)
          context.set_source_pixbuf(icon)
          context.paint
        }
        icon
      }
      unless @pixels.empty? || @reset_heighted
        @reset_heighted = true
        helper.reset_height
      end
    end

    def height
      if @pixels.empty? then
        0
      else
        @pixels.max_by { |x| x.height } .height
      end
    end
  end
}
