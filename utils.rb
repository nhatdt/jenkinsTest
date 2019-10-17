# -*- encoding: utf-8 -*-
require 'net/http'
require 'rack/utils'
require 'yaml'
require 'aws-sdk'

require_relative 'config'
require_relative 'aws4_signer'

class RequestException < Exception
  attr_reader :origin_exception

  def initialize(error_message=nil, origin_exception=nil)
    super(error_message)
    @origin_exception = origin_exception
  end
end


module NCApplication
module Utils

  class << self

    # 同期並列実行
    # @param [Hash] thread_safe_lambdas
    # @return [Hash]
    def async_parallel(thread_safe_lambdas)
      response = {}
      threads = []
      mutex = Mutex.new
      thread_safe_lambdas.each do |key, a_lambda|
        threads << Thread.start(key, a_lambda) do |k, l|
          r = l.call
          mutex.synchronize { response[k] = r }
        end
      end
      threads.each(&:join)
      response
    end

    def require_real(path)
      fn = File.expand_path('../../', __FILE__)
      require_relative File.join(fn, path)
    end

    def require_src(path)
      fn = NCApplication::Config.instance[:dir][:src]
      require_relative File.join(fn, path)
    end

    # @ return [Object, FalseClass]
    def load_yaml(yaml_path)
      ret = ::YAML.load_file(yaml_path + '.yml')
    end

    def request_get(host, path, param)
      start(host, Net::HTTP::Get.new(path << '?' << Rack::Utils.build_query(param)), {})
    end

    #
    # API Gatewayによって作成されたAPIへGETリクエストする
    #
    # @param [string] server_name サーバー名(host名)
    # @param [string] path リクエストパス
    # @param [hash] params リクエストパラメータ
    # @param [string] arn_name amazon resource name
    # @param [hash] opts リクエスト用オプション
    def request_get_to_apigateway(server_name, path, params, arn_name, opts = {}, signer_opts = {})
      uri = URI.parse(server_name + path)
      uri.query = Rack::Utils.build_query(params)

      # assume roleによるcredentialsを使って通信する
      # 使用しなくても理屈上はOKだが、社内のセキュリティ規約をクリアするために
      # 現状許可が降りているのがこの手法のみ
      sts = Aws::STS::Client.new
      assumed_role = sts.assume_role(
        :role_arn => arn_name,
        :role_session_name => 'ncapplication'
      )

      # credentialsを利用してAWS V4署名を発行
      signer = NCApplication::Aws4Signer.new(
        assumed_role[:credentials],
        uri,
        opts[:headers],
        signer_opts
      )

      req = Net::HTTP::Get.new(
        "#{uri.path}?#{uri.query}",
        signer.get_signatured_headers
      )
      start(uri.host, req, opts)
    end

    def start(server_name, req, opt)
      retry_count = opt[:retry] || 0
      open_timeout = opt[:open_timeout]
      read_timeout = opt[:read_timeout]
      use_ssl = opt[:use_ssl]

      connect = Net::HTTP.new(server_name, use_ssl ? 443 : 80)
      use_ssl and connect.use_ssl = use_ssl
      open_timeout and connect.open_timeout = open_timeout
      read_timeout and connect.read_timeout = read_timeout

      count = 0
      begin
        res = connect.request(req)
      rescue => e
        count += 1
        count <= retry_count and retry
        if 0 < retry_count
          raise RequestException.new("over retry count #{retry_count}", e)
        else
          raise e
        end
      end
      res and return res.body
      nil
    end

    # ハッシュの深いマージを行う
    # キーが衝突した場合でも、中身がハッシュであれば中身だけマージする
    # 中身のキーが衝突した場合は、第2引数で渡したハッシュの値が優先される
    #
    # @param [Hash] params マージされるハッシュパラメータ
    # @param [Hash] merge_params マージするハッシュパラメータ
    # @return [Hash] マージ後のパラメータ
    #
    def hash_deep_merge(params, merge_params)
      # 引数がハッシュでない場合は第2引数をそのまま返却
      params.is_a?(::Hash) or return merge_params
      merge_params.is_a?(::Hash) or return merge_params

      copy_params = Marshal.load(Marshal.dump(params))
      merge_params.each do |key, val|
        # 片方にしか存在しないキーの場合はその値をそのままマージ
        unless copy_params.key?(key)
          copy_params[key] = val
          next
        end
        # マージ対象のパラメータがハッシュだった場合は再帰的にマージ
        copy_params[key] = hash_deep_merge(copy_params[key], val)
      end
      copy_params
    end

    # hashのキーをStringで統一したhashを返す
    def string_key_hash(hash)
      raise TypeError, hash.inspect+' is not Hash' unless hash.instance_of?(Hash)

      hash.each do |key, value|
        hash[key] = string_key_hash(value) if value.instance_of?(Hash)
      end
      Hash[hash.map { |k, v| [k.to_s, v] }]
    end

    # Sinatraで生成されたparamsにdefault_procが設定されているため、
    # Marshalを利用しないでパラメタを複製する
    #
    # @param [Hash] params パラメータ
    # @return [Hash] 複製したパラメータ
    #
    def hash_deep_copy(params)
      if params.is_a?(Hash)
        data = {}
        params.each do |k, v|
          data[k] = hash_deep_copy(v)
        end
        return data
      end
      params
    end

    # 文字列埋め
    #
    # @params [Array] values 埋められる文字列の配列
    # @params [String] padstr 埋める文字列
    # @params [Integer] length 桁数
    # @params [Integer] excluded 除外する数値 (falsyなあたりをto_iした時や0を除外したい場合は0を指定する)
    # @return [Array] 埋めた結果
    def rjust_strs(values, padstr, length, excluded = nil)
      return [] unless valid_args_for_rjust_strs?(values, padstr, length, excluded)
      values.map(&:to_s).map(&:to_i).select { |v| v != excluded }.map(&:to_s).map { |v| v.rjust(length, padstr) }
    end

    # rjust_strs のバリデーション
    #
    # @params [Array] values 埋められる文字列の配列
    # @params [String] padstr 埋める文字列
    # @params [Integer] length 桁数
    # @params [Integer] excluded 除外する数値
    # @return [Boolean]
    def valid_args_for_rjust_strs?(values, padstr, length, excluded)
      return false unless values.is_a?(Array) || padstr.is_a?(String) || length.is_a?(Integer) || excluded.nil? || excluded.is_a?(Integer)
      true
    end
  end

  # = マルチスレッド対応名前管理コンテナ
  #
  # TODO: ヘルプ書く
  # initializeメソッドは定義してあってもよい
  # 一度作ったオブジェクトを保持するためのクラスであるので、
  # Mix-in対象のクラスはSingletonにはならない
  #
  module InstanceHosting
    class << self

      # モジュールインクルードフックメソッド
      #
      # @param [Object] klass モジュールを include したクラス
      # @return [Object] モジュールを include したクラス
      #
      def included(klass)

        klass.instance_eval do
          @nx_instance__pocket__ = {}
          @nx_instance__mutex__ = Mutex.new
        end

        class << klass

          # インスタンスを分け与える
          # なければ生成する
          # 引数は任意の数の引数をとるが、
          # 最初の要素はメソッドを保持するキー名である
          #
          # @param [Mixed] args 上記の注意書きを参照
          # @return [Object, nil] キー名が指定されていない場合は nil を返却
          #
          def share(*args)
            key = args.shift or return
            key = key.to_sym
            (item = @nx_instance__pocket__[key]) and return item.dup
            @nx_instance__mutex__.synchronize do
              (item = @nx_instance__pocket__[key]) and return item.dup
              @nx_instance__pocket__[key] = (args.empty? ? new() : new(*args))
            end
            @nx_instance__pocket__[key]
          end

          # 指定されたキー名で格納されているインスタンスの存在確認を行う
          # 共有できる状態 (= 名前付きインスタンス)
          #
          # @param [#to_s] key 格納しているキー名
          # @return [true, false] 存在するときは true
          #
          def share?(key)
            @nx_instance__pocket__.key?(key.to_sym)
          end

          # 指定されたキー名で格納されているインスタンスを取得する
          #
          # @param [#to_s] key 格納しているキー名
          # @return [Object] したいされたキー名で登録されたインクルード元のインスタンス
          #
          def [](key)
            @nx_instance__pocket__[key.to_sym]
          end

        end

        klass
      end
    end
  end

  #########################################################################
  # 当モジュールは NextCore/lib/utils/lib/formatter.rb とほぼ同一の内容です
  #########################################################################
  module Formatter
    # InvalidNumberError は定義されていないので、
    # エラーを別途作成して対応する
    class InvalidNumberError < Exception
    end

    class << self
      # number_format
      # rails/actionpack/lib/action_view/helpers/number_helper.rb
      # Ruby on Rails pluginの多言語対応やその他オプション、rails用の機能を削ぎ落したもの
      # MIT ライセンスで改変は自由だが著作権者の明示が必要。
      # https://github.com/rails/rails/blob/006de2577a978cd212f07df478b03053b1309c84/actionpack/lib/action_view/helpers/number_helper.rb#L231
      # ここを参照したものだが、著作権はRuby on Rails？
      # @param [Mixed] ナンバーフォーマットしたいパラメータ
      # @return [String] ナンバーフォーマットしたパラメータ
      def number_format(number, options = {})
        begin
          Float(number)
        rescue ArgumentError, TypeError
          options[:raise] and raise InvalidNumberError, number
          return number
        end

        defaults = {delimiter: ',', separator: '.'}
        options = defaults.merge(options)
        parts = number.to_s.split('.')
        parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")

        # オプション指定があった時、小数点以下の0を消さない
        if options[:need_decimal_zero]
          parts.join(options[:separator])
        else
          (parts[1] == '0') ? parts[0] : parts.join(options[:separator])
        end
      end
    end
  end

end
end
