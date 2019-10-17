# -*- encoding: utf-8 -*-
require_relative 'base'
require_relative 'pref'
require_relative 'town'
NCApplication::Utils.require_src 'data/dao'

module NCApplication
module Model

# 市区町村クラス
class City < NCApplication::Model::Base

  # @return [String] 市区町村ID
  attr_reader :id

  # @return [String] 名称
  attr_reader :name

  # @return [String] ローマ字
  attr_reader :roman

  # @return [String] ルビ
  attr_reader :ruby

  # @return [String] ルビひらがな
  attr_reader :kana

  # @return [String] 都道府県ID
  attr_reader :pref_id

  # @return [String] 政令指定都市ID
  attr_reader :major_city_id

  # @return [String] 政令指定都市名称
  attr_reader :major_city_name

  # @return [String] 政令指定都市ローマ字
  attr_reader :major_city_roman

  # @return [String] 政令指定都市ルビ
  attr_reader :major_city_ruby

  # @return [String] 政令指定都市ルビひらがな
  attr_reader :major_city_kana

  # @return [String] 名称（政令指定都市の区名）
  attr_reader :major_city_part_name

  # @return [String] ルビ（政令指定都市の区名）
  attr_reader :major_city_part_ruby

  # @return [String] ルビひらがな（政令指定都市の区名）
  attr_reader :major_city_part_kana

  # @return [Integer] 緯度（日本測地系 ミリ秒）
  attr_reader :nl

  # @return [Integer] 経度（日本測地系 ミリ秒）
  attr_reader :el

  # @return [Float] 緯度（世界測地系 度）
  attr_reader :lat

  # @return [Float] 経度（世界測地系 度）
  attr_reader :lng

public

  class << self
    # @param [String] id 市区町村ID
    # @return [NCApplication::Model::City] 市区町村
    def get(id)
      self.get_once(id) do | safe_id |
        NCApplication::Dao.instance.get_city(safe_id)
      end
    end

    # @param [String] id 都道府県id
    # @return [Hash] 市区町村
    def get_by_pref_id(id)
      self.get_list(id) do | safe_id |
        NCApplication::Dao.instance.get_city_by_pref_id(safe_id)
      end
    end

    # @param [String] id 政令指定都市id
    # @return [Hash] 市区町村
    def get_by_major_city_id(id)
      self.get_list(id) do | safe_id |
        NCApplication::Dao.instance.get_city_by_major_city_id(safe_id)
      end
    end

    # @param [String] id 政令指定都市id
    # @return [Hash] 市区町村ID
    def get_city_ids_by_major_city_id(id)
      self.get_ids_list(id) do
        NCApplication::Dao.instance.get_city_ids_by_major_city_id(id)
      end
    end

    # @param [String] roman 市区町村ローマ字
    # @param [String] pref_id 都道府県ID
    # @return [NCApplication::Model::City] 市区町村
    def get_by_roman(roman, pref_id)
      self.get_once(roman) do
        city = NCApplication::Dao.instance.get_city_by_roman(roman)
        # 市区町村のローマ字の場合、複数の市区町村が一致することがあるため
        # 都道府県コードを利用して、一意にします
        # ex. konan, tsushima, etc...
        #
        # また、ローマ字が設定されていない市区町村もあります
        # その場合、マスタにはIDをKEYとしてインデックスが登録されています
        # ex. 01695. 13420, etc...
        ret = nil
        unless city.blank?
          pref_id = pref_id.to_s.rjust(2, '0')
          city.each do |city_id, dt|
            (dt['pref_id'] != pref_id) and next
            ret = dt
            break
          end
        end
        ret
      end
    end
  end

  # @return [Pref] 都道府県
  def pref
    cache(:pref) { Pref.get(@pref_id) }
  end

  # @return [Hash] 町域
  def town
    cache(:town) { Town.get_by_city_id(@id) }
  end

end

end
end
