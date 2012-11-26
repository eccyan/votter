require 'nokogiri'
require 'open-uri'
require "net/http"
require "uri"
require "pry"
require "csv"
require "ipaddress"
require 'timeout'

# プロキシIPのリストを取得する
ips = []
CSV.foreach("proxy.csv", col_sep:"\;") do |row|
  if IPAddress.valid? row[0]
    ips.push row[0]
  end
end

# タイムアウトを設定するためのパッチ
class Net::HTTP
  def initialize_new(address, port = nil)
    initialize_old(address, port)
    @read_timeout = 3
  end

  alias :initialize_old :initialize
  alias :initialize :initialize_new
end

ips.each do |ip|
  begin
    uri = URI.parse("http://example.com/vote/")

    page = open(uri, proxy:"http://#{ip}:8080")
    # ページopen 時のクッキーを取得しAPIポスト時に使う
    cookie = page.meta['set-cookie'].split('; ',2)[0]
    doc = Nokogiri::HTML(page)
    
    # ページからTokenを取得
    token = nil
    doc.xpath('//html/body/form[1]/input[2]').each do |input|
      token = input.attr('value')
    end
    
    api_uri = URI.parse("http://example.com/vote/poll.php")
    
    proxy = Net::HTTP::Proxy(ip, 8080)
    http = proxy.new(api_uri.host, api_uri.port)
    
    http.start do |h|
      request = Net::HTTP::Post.new(api_uri.request_uri)
      request.set_form_data({"answer" => "yes", "token" => token, "question_id" => "1"})
      request["Cookie"] = cookie
      request["Host"] = uri.host
      request["Origin"] = uri.host
      request["Referer"] = "#{uri}"
      request["User-Agent"] = "from eccyan" # UA はブラウザのUAに変更しましょう！
    
      response = h.request(request)
      if response.code == '302'
        puts "#{ip}:succeeded"
      else
        puts "#{ip}:failed #{response}"
      end
    end

  rescue => e
    # とりあえず例外はログに残して無視
    # Timeout も飛んでくる
    puts "#{ip}:failed #{e}"
  end
end
