require 'open-uri'
require "net/http"
require "uri"
require "csv"
require "pry"
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
    puts "start with #{ip}"
    uri = URI.parse("http://www.jaftma-jaff.com/idol")
    
    api_uri = URI.parse("http://www.jaftma-jaff.com/idol/index.php")
    
    proxy = Net::HTTP::Proxy(ip, 8080)
    http = proxy.new(api_uri.host, api_uri.port)
    
    http.start do |h|
      request = Net::HTTP::Post.new(api_uri.request_uri)
      request.set_form_data({"date" => "#{Time.now.to_i}0000'", "act" => "vote", "id" => "3"})
      #request["Cookie"] = cookie
      request["Host"] = uri.host
      request["Origin"] = uri.host
      request["Referer"] = "#{uri}"
      request["User-Agent"] = "Mozilla/5.0 (Linux; U; Android 2.3.6; en-us; Nexus S Build/GRK39F) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1"
    
      response = h.request(request)
      if response.code == '200'
        puts "#{ip}:succeeded"

        sleep_seconds = (rand(10) * 60)
        puts "sleeping... #{sleep_seconds}"

        sleep sleep_seconds
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
