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
      @photos.each { |photo|
        photo.download(width: self.width,
                       height: UserConfig[:mikutter_sub_parts_image_flex_max_height])
      }
      @reseted_height = false
    end

    def render(context)
      # 処理を多少軽くする
      if @photos.empty?
        return
      end
      @pixbufs = @photos.map.with_index { |photo, index|
        w = self.width / @photos.length
        h = UserConfig[:mikutter_sub_parts_image_flex_max_height]
        pixbuf = photo.pixbuf(width: w, height: h)
        if pixbuf
          # @reseted_heightを参照することで,heightが縮小する場合に正しく計算がされないが,
          # チラツキの予防のため仕方のない犠牲と諦める
          # resetするのは最後のphoto読み込みの場合のみ
          if !@reseted_height && index == @photos.length - 1
            @reseted_height = true
            helper.reset_height
          end
          pixbuf
        else
          photo.download_pixbuf(width: w, height: h).next {
            helper.on_modify
          }.trap {
            Delayer.new {
              @photos.delete(photo)
              helper.on_modify
            }
          }
          nil
        end
      }.compact
      @pixbufs.each.with_index { |pixbuf, index|
        context.save {
          context.translate(index * (self.width / @pixbufs.length), 0)
          context.set_source_pixbuf(pixbuf)
          context.paint
        }
      }
    end

    def height
      if @pixbufs.empty?
        0
      else
        [@pixbufs.map(&:height).max, UserConfig[:mikutter_sub_parts_image_flex_max_height]].min
      end
    end
  end
}
