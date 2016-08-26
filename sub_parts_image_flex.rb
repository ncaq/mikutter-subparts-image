# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

Plugin.create(:sub_parts_image_flex) {
  UserConfig[:sub_parts_image_flex_max_height] ||= 300

  settings("インライン画像表示") {
    adjustment("画像の最大縦幅(px)", :sub_parts_image_flex_max_height, 0, 10000)
  }

  class Gdk::SubPartsImageFlex < Gdk::SubParts
    regist

    def initialize(*args)
      super
      @main_icons = []

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
          @main_icons[index] = pixbuf
        }
      end
    end

    # サブパーツを描画
    def render(context)
      @main_icons.map!.with_index { |icon, i|
        max_width = self.width / @main_icons.length
        draw_rect = Gdk::Rectangle.new(
          i * max_width, 0, max_width, UserConfig[:sub_parts_image_flex_max_height])

        hscale = draw_rect.height.to_f / icon.height
        icon = icon.scale(icon.width * hscale, icon.height * hscale)

        if draw_rect.width < icon.width then # 横幅がはみ出していたらscaleし直す
          wscale = draw_rect.width.to_f / icon.width
          icon = icon.scale(icon.width * wscale, icon.height * wscale)
        end

        context.save {
          context.translate(draw_rect.x, draw_rect.y)
          context.set_source_pixbuf(icon)
          context.paint
        }
        icon
      }
      unless @main_icons.empty? || @reset_heighted
        @reset_heighted = true
        helper.reset_height
      end
    end

    def height
      if @main_icons.empty? then
        0
      else
        @main_icons.max_by { |x| x.height } .height
      end
    end
  end
}
