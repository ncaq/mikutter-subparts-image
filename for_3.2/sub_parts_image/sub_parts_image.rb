# -*- coding: utf-8 -*-
miquire :mui, 'sub_parts_helper'

require 'gtk2'
require 'cairo'

Plugin.create :sub_parts_image do
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

    # イメージ取得完了
    def on_image_loaded(pos, pixbuf)
      # puts "#{@helper_message[0..10]} image loaded start #{pos}"

      if !helper.destroyed?
        # 再描画イベント
        sid = helper.ssc(:expose_event, helper) {
          # サブパーツ描画
          helper.on_modify
          helper.signal_handler_disconnect(sid)
          false
        }
      end

      # サブパーツ描画
      @main_icons[pos] = pixbuf

      # puts "#{@helper_message[0..10]} draw ready #{pos}"

      Delayer.new {
        # puts "#{@helper_message[0..10]} draw image #{pos}"
        helper.on_modify
      }
    end

    # 画像URLが解決したタイミング
    def on_image_information(urls)
      if urls.length == 0
        return
      end

      @mutex.synchronize {
        @num = urls.length

        if @height_reported
          Delayer.new {
            helper.reset_height
          }
        end
      }

      if !helper.destroyed?
        # クリックイベント
        @ignore_event = false

        if @click_sid
          helper.signal_handler_disconnect(@click_sid)
          @click_sid = nil
        end

        @click_sid = helper.ssc(:click) { |this, e, x, y|
          # クリック位置の特定
          offset = helper.mainpart_height

          helper.subparts.each { |part|
            if part == self
              break
            end

            offset += part.height
          }

          clicked_url, = urls.lazy.with_index.map{|url, pos|
            rect = image_draw_area(pos, self.width)
            [url, rect.x ... rect.x+rect.width, rect.y+offset ... rect.y+offset+rect.height]
          }.find{|url, xrange, yrange|
            xrange.include?(x) and yrange.include?(y) }
          case e.button
          when 1
            Plugin.call(:openimg_open, clicked_url) if clicked_url
          end

        }
      end
    end

    # コンストラクタ
    def initialize(*args)
      super
      @num = 0
      @height_reported = false
      @mutex = Mutex.new
      @main_icons = []

      @helper_message = helper.message[:message]

      if message
        # イメージ読み込みスレッドを起こす
        Thread.new(message) { |message|
          urls = message.entity
                 .select{ |entity| %i<urls media>.include? entity[:slug] }
                 .map { |entity|
            case entity[:slug]
            when :urls
              entity[:expanded_url]
            when :media
              entity[:media_url]
            end
          } + Array(message[:subparts_images])

          streams = urls.map{ |url| Plugin.filtering(:openimg_raw_image_from_display_url, url, nil) }
                    .select{ |pair| pair.last }

          Delayer.new{ on_image_information streams.map(&:first) }

          streams.each.with_index do |pair, index|
            _, stream = *pair
            Thread.new {
              pixbuf = Gdk::PixbufLoader.open{ |loader|
                loader.write(stream.read)
                stream.close
              }.pixbuf

              Delayer.new {
                on_image_loaded(index, pixbuf)
              }
            }.trap{ |exception|
              puts "#{@helper_message[0..10]} #{exception}"
              error exception
            }
          end
        }.trap{ |exception| error exception }
      end
    end

    # 画像表示位置をキーにアスペクト比を求める
    def aspect_ratio(pos)
      case @num
      when 1, 4
        Rational(16, 9)
      when 2
        Rational(1, 1)
      when 3
        if pos == 0
          Rational(6, 9)
        else
          Rational(20, 9)
        end
      else
        Rational(16, 9)
      end
    end

    def aspect_ratio_x(pos)
      aspect_ratio(pos).numerator
    end

    def aspect_ratio_y(pos)
      aspect_ratio(pos).denominator
    end

    # 画像を描画する座標とサイズを返す
    # ==== Args
    # [pos] Fixnum 画像インデックス
    # [canvas_width] Fixnum キャンバスの幅(px)
    # ==== Return
    # Gdk::Rectangle その画像を描画する場所
    def image_draw_area(pos, canvas_width)
      case @num
      when 1
        height = 1 / aspect_ratio(pos) * canvas_width
        Gdk::Rectangle.new(0, height * pos, canvas_width, height)
      when 2
        width = canvas_width / 2
        height = 1 / aspect_ratio(pos) * width
        Gdk::Rectangle.new(width * pos, 0, width, height)
      when 3
        if pos == 0
          width = Rational(6, 16) * canvas_width
          height = 1 / aspect_ratio(pos) * width
          Gdk::Rectangle.new(0, 0, width, height)
        else
          x = Rational(6, 16) * canvas_width
          width = canvas_width - x
          height = 1 / aspect_ratio(pos) * width
          Gdk::Rectangle.new(x, height * (pos - 1), width, height)
        end
      else
        width = canvas_width / 2
        height = 1 / aspect_ratio(pos) * width
        Gdk::Rectangle.new(width * (pos % 2), height * (pos / 2).floor, width, height)
      end
    end

    # 画像を切り抜くさい、どこを切り抜くかを返す
    # ==== Args
    # [pos] Fixnum 画像インデックス
    # [base_area] Gdk::Pixbuf|Gdk::Rectangle 画像の寸法
    # [draw_area] Gdk::Rectangle 描画する場所の寸法
    # ==== Return
    # Gdk::Rectangle base_area内の切り抜く位置
    def image_crop_area(pos, base_area, draw_area)
      x_ratio = Rational(base_area.width, aspect_ratio_x(pos))
      y_ratio = Rational(base_area.height, aspect_ratio_y(pos))
      if x_ratio == y_ratio
        Gdk::Rectangle.new(0, 0, base_area.width, base_area.height)
      elsif x_ratio < y_ratio
        height = Rational(base_area.width * aspect_ratio_y(pos), aspect_ratio_x(pos))
        Gdk::Rectangle.new(0, (base_area.height - height) / 2, base_area.width, height)
      else
        width = Rational(base_area.height * aspect_ratio_x(pos), aspect_ratio_y(pos))
        Gdk::Rectangle.new((base_area.width - width) / 2, 0, width, base_area.height)
      end
    end

    # サブパーツを描画
    def render(context)
      @main_icons.compact.map.with_index { |icon, pos|
        draw_rect = image_draw_area(pos, self.width)
        crop_rect = image_crop_area(pos, icon, draw_rect)
        [icon, draw_rect, crop_rect]
      }.each { |icon, draw_rect, crop_rect|
        context.save {
          scale_x = Rational(draw_rect.width, crop_rect.width)
          scale_y = Rational(draw_rect.height, crop_rect.height)

          context.translate(draw_rect.x - (icon.width - crop_rect.width) * scale_x / 2,
                            draw_rect.y - (icon.height - crop_rect.height) * scale_y / 2)
          context.scale(scale_x, scale_y)
          context.set_source_pixbuf(icon)

          context.clip {
            context.rounded_rectangle(crop_rect.x, crop_rect.y, crop_rect.width, crop_rect.height, 0)
          }

          context.paint
        }
      }
    end

    def height
      @mutex.synchronize {
        @height_reported = true
        if @num == 0
          0
        else
          draw_rect = image_draw_area(@num - 1, width)
          draw_rect.y + draw_rect.height
        end
      }
    end


    private

    def message
      helper.message
    end
  end
end
