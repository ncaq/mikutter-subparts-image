# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

Plugin.create :sub_parts_image do
  UserConfig[:subparts_image_tp] ||= 100
  UserConfig[:subparts_image_max_height] ||= 400

  settings "インライン画像表示" do
    adjustment("濃さ(%)", :subparts_image_tp, 0, 100)
    adjustment("画像の最大縦幅(px)", :subparts_image_max_height, 0, 10000)
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
  class Gdk::SubPartsImage < Gdk::SubParts
    regist

    # 画像URLが解決したタイミングで起動し,クリックイベントを設定する
    def on_image_information(urls)
      if urls.length == 0
        return
      end
      helper.reset_height
      helper.ssc(:click) { |this, e, x, y|
        if e.button == 1        # 左クリック
          # クリック位置の特定
          offset = helper.mainpart_height +
                   helper.subparts.take_while { |part| part != self }.map(&:height).inject(0, :+)
          clicked_url, = urls.find.with_index { |url, pos|
            rect = image_draw_area(pos, self.width)
            xrange = rect.x          ... rect.x + rect.width
            yrange = rect.y + offset ... rect.y + rect.height + offset
            xrange.cover?(x) && yrange.cover?(y)
          }
          Plugin.call(:openimg_open, clicked_url) if clicked_url
        end
      }
    end

    # コンストラクタ
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
        } + Array(helper.message[:subparts_images])
        streams = urls.map { |url|
          Plugin.filtering(:openimg_raw_image_from_display_url, url, nil)
        }.select(&:last)
        on_image_information(streams.map(&:first))
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

    # 画像を描画する座標とサイズを返す
    # ==== Args
    # [pos] Fixnum 画像インデックス
    # [canvas_width] Fixnum キャンバスの幅(px)
    # ==== Return
    # Gdk::Rectangle その画像を描画する場所
    def image_draw_area(pos, canvas_width)
      max_width = UserConfig[:subparts_image_max_height] * Rational(16, 9)
      width = [canvas_width / @main_icons.length, max_width].min
      height = width / Rational(16, 9)
      x = width * pos
      y = 0
      Gdk::Rectangle.new(x, y, width, height)
    end

    # サブパーツを描画
    def render(context)
      @main_icons.compact.each.with_index { |icon, pos|
        draw_rect = image_draw_area(pos, self.width)
        wscale = draw_rect.width.to_f  / icon.width
        hscale = draw_rect.height.to_f / icon.height
        scale = [wscale, hscale].min # アスペクト比を保ち,はみ出さない範囲のスケール
        icon = icon.scale(icon.width * scale, icon.height * scale)
        context.save {
          context.translate(draw_rect.x, draw_rect.y)
          context.set_source_pixbuf(icon)
          context.paint(UserConfig[:subparts_image_tp] / 100.0)
        }
      }
    end

    def height
      if @main_icons.length == 0
        0
      else
        draw_rect = image_draw_area(@main_icons.length - 1, self.width)
        draw_rect.y + draw_rect.height
      end
    end
  end
end
