require 'sinatra/base'
require 'net/http'

require 'snifter_globals'

trap('CLD') do
  if pid = Process.wait(-1, Process::WNOHANG)
    puts "Snifter [#{pid}] stopped."
    $snifters.stopped pid
  end
end

$snifters.each do |snifter|
  snifter.verify_pid!
end

class SnifterFrontend < Sinatra::Base
  set :root, File.expand_path('..', File.dirname(__FILE__))
  enable :method_override

  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

    def snifter
      $snifters[params[:snifter_id]]
    end
  end

  get '/' do
    erb :index
  end

  post '/snifter' do
    puts params.inspect
    snifter_id = params[:snifter_id]
    snifter_id = Time.now.to_i.to_s if snifter_id.nil? || snifter_id.empty?
    snifter = $snifters.add snifter_id, params[:snifter]
    snifter.start! if params[:start]
    redirect to('/')
  end

  delete '/:snifter_id' do
    $snifters.remove params[:snifter_id]
    redirect to('/')
  end

  get '/compare' do
    unless snifter_a = $snifters[params[:a]]
      redirect to('/')
    else
      unless snifter_b = $snifters[params[:b]]
        erb :choose_other, :locals => { :a => snifter_a, :choices_for_b => $snifters.reject { |snifter| snifter.id == snifter_a.id } }
      else
        erb :compare, :locals => { :a => snifter_a, :b => snifter_b }
      end
    end
  end

  get '/compare/session' do
    [:a, :b].map { |side|
      req, res = $snifters[params[side][:id]].session(params[side][:sess])
      '<div class="comparison">' + erb(:session, :locals => { :req => req, :res => res }, :layout => false) + '</div>'
    }.join('')
  end

  get '/:snifter_id' do
    erb :snifter, :locals => { :snifter => snifter }
  end

  post '/:snifter_id/start' do
    snifter.start!
    redirect to(params[:return_to] || '/')
  end

  post '/:snifter_id/stop' do
    snifter.stop!
    redirect to(params[:return_to] || '/')
  end

  get '/:snifter_id/:sess' do
    req, res = snifter.session(params[:sess])
    erb :session, :locals => { :req => req, :res => res }, :layout => false
  end

  get '/:snifter_id/:sess/raw' do
    req, res = snifter.raw_session(params[:sess])
    '<pre>' + h(req.to_s + "\r\n\r\n######## response ########\r\n\r\n" + res.to_s) + '</pre>'

  end

  get '/:snifter_id/:sess/tweak' do
    req = snifter.raw_session(params[:sess]).first
    erb :tweak, :locals => { :req => req, :host => "127.0.0.1:#{snifter.port}" }, :layout => false
  end

  delete '/:snifter_id/sessions' do
    snifter.clear!
    redirect to("/#{snifter.id}")
  end

  post '/:snifter_id/session' do
    name = params[:session_name] || 'ls /svn'
    sessions = params[:sessions]
    snifter.save_group(name, sessions)
    redirect to("/#{snifter.id}")
  end

  post '/custom_request' do
    response = run_request :host => params[:host], :raw_request => params[:request]
    "<pre>" + h(response) + "</pre>"
  end

  class RawRequest < Net::HTTPGenericRequest
    def initialize(raw_request)
      @raw_header, @raw_body = raw_request.split(/\r\n\r\n/)
      @raw_header =~ /^(\w+)\s+(\S+)/
      super($1, !@raw_body.nil?, true, $2, nil)
      @body = @raw_body
    end

    def write_header(sock, ver, path)
      sock.write @raw_header + "\r\n\r\n"
    end
  end

  def run_request opts
    host, raw_request = opts[:host], opts[:raw_request]
    hostname, port = host.split(/:/)
    http = Net::HTTP.new hostname, port
    http.set_debug_output $stdout
    http.start do
      request = RawRequest.new raw_request
      response = http.request request
      back_to_raw response
    end
  end

  def back_to_raw response
    [
      "HTTP/#{response.http_version} #{response.code} #{response.msg}",
      response.each_capitalized_name.each_with_object([]) { |k,a| response.get_fields(k).each { |v| a << "#{k}: #{v}" } },
      '',
      response.body
    ].flatten.join("\r\n")
  end

  #post '/:snifter_id/session' do
  #  @snifter = $snifters[params[:snifter_id]]
  #  @snifter.start_session params[:session]
  #  redirect to("/#{@snifter.id}")
  #end
  #
  #get '/:snifter_id/requests' do
  #  @snifter = $snifters[params[:snifter_id]]
  #  erb :all_requests
  #end
  #
  #get '/:snifter_id/request/:request_id' do
  #end
end
