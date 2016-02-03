require 'net/http'
require 'net/https'
require 'http/cookie'
require 'pp'
 
class HttpSession
    def initialize(url = nil)
        @http = nil
        @uri = nil
        @session = {}
        @cookie = HTTP::CookieJar.new
        @cookie_file = "#{File.dirname(__FILE__)}/cookie"
        @cookie.load(@cookie_file) if File.exist?(@cookie_file)
        update_session(url) if url
        ObjectSpace.define_finalizer(self) {|id| close()}
    end
    private
    def update_session(path)
        uri = URI.parse(path)
        if (uri.host.nil? && @uri) || (get_key(uri) == get_key(@uri))
            @uri.path = uri.path
        elsif uri.host && (get_key(uri) != get_key(@uri))
            @http = @session[get_key(uri)]
            @http ||= @session[get_key(uri)] = Net::HTTP.start(uri.host,
                                                               uri.port,
                                                               use_ssl: (uri.scheme == 'https'),
                                                               verify_mode: OpenSSL::SSL::VERIFY_NONE)
            @uri = uri
        end
    end
    def get_key(uri)
        uri ? :"#{uri.host}:#{uri.port}" : nil
    end
    def set_cookie(request)
        cookies = @cookie.cookies(@uri)
        request["Cookie"] = HTTP::Cookie.cookie_value(cookies) unless cookies.empty?
    end
    def update_cookie(response)
        cookies = response.get_fields("Set-Cookie") || [] 
        cookies.each do |value|
            @cookie.parse(value, @uri)
        end
    end

    public
    def close()
        puts "HttpSession<#{self.object_id}> closed."
        @cookie.save(@cookie_file)
        @session.each_value do |http|
            http.finish
        end
    end
    def sync_get(path, username=nil, password=nil)
        raise "Invalid path, sync get failed!" if path.nil?
        update_session(path)
        req = Net::HTTP::Get.new(path)
        req.basic_auth(username, password) if (username && password)
        set_cookie(req)
        puts "GET: #{@uri.to_s}"
        res = @http.request(req)
        update_cookie(res)
        return res
    end
    def sync_post(path, username=nil, password=nil, content)
        raise "Invalid path, sync get failed!" if path.nil?
        update_session(path)
        req = Net::HTTP::Post.new(path)
        req.basic_auth(username, password) if (username && password)
        set_cookie(req)
        req.content_type = content[:type] if content[:type]
        req.body = content[:value] if content[:value]
        puts "POST: #{@uri.to_s}"
        res = @http.request(req)
        update_cookie(res)
        return res
    end
end