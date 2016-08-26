# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

Plugin.create :sub_parts_image_flex do
  UserConfig[:sub_parts_image_flex_max_height] ||= 300

  settings "インライン画像表示" do
    adjustment("画像の最大縦幅(px)", :sub_parts_image_flex_max_height, 0, 10000)
  end

  defimageopener('youtube thumbnail (shrinked)', /^http:\/\/youtu.be\/([^\?\/\#]+)/) do |url|
    /^http:\/\/youtu.be\/([^\?\/\#]+)/.match(url)
    open("http://img.youtube.com/vi/#{$1}/0.jpg")
  end

  defimageopener('youtube thumbnail', /^https?:\/\/www\.youtube\.com\/watch\?v=([^\&]+)/) do |url|
    /^https?:\/\/www\.youtube\.com\/watch\?v=([^\&]+)/.match(url)
    open("http://img.youtube.com/vi/#{$1}/0.jpg")
  end

  defimageopener('niconico video thumbnail(shrinked)', /^http:\/\/nico.ms\/sm([0-9]+)/) do |url|
    /^http:\/\/nico.ms\/sm([0-9]+)/.match(url)
    open("http://tn-skr#{($1.to_i % 4) + 1}.smilevideo.jp/smile?i=#{$1}")
  end

  defimageopener('niconico video thumbnail', /nicovideo\.jp\/watch\/sm([0-9]+)/) do |url|
    /nicovideo\.jp\/watch\/sm([0-9]+)/.match(url)
    open("http://tn-skr#{($1.to_i % 4) + 1}.smilevideo.jp/smile?i=#{$1}")
  end

  # サブパーツ
  class Gdk::SubPartsImageFlex < Gdk::SubParts
    regist

    def initialize(*args)
      super
      @main_icons = []
      @draw_rects = []

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
        # 全ての画像の処理が終わったら縦幅を再計算
        helper.reset_height
      end
    end

    # サブパーツを描画
    def render(context)
      @main_icons.compact.each.with_index { |icon, i|
        width = self.width.to_f / @main_icons.length
        height = UserConfig[:sub_parts_image_flex_max_height]
        @draw_rects[i] = Gdk::Rectangle.new(i * width, 0, width, height)

        wscale = @draw_rects[i].width / icon.width
        icon = icon.scale(wscale, wscale)

        if height < icon.height then # heightがはみ出していたら
          hscale = @draw_rects[i].height / icon.height
          icon = icon.scale(hscale, hscale) # hscaleで拡大しなおし
        end

        context.save {
          context.translate(@draw_rects[i].x, @draw_rects[i].y)
          context.set_source_pixbuf(icon)
          context.paint()
        }
      }
    end

    def height
      if @draw_rects.empty? then
        0
      else
        @draw_rects.max_by { |x| x.height } .height
      end
    end
  end
end
