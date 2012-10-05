require 'sinatra/base'

require 'snifter_globals'

trap('CLD') do
  if pid = Process.wait(-1, Process::WNOHANG)
    puts "Snifter [#{pid}] stopped."
    $snifters.stopped pid
  end
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
    content_type :text
    req.to_s + "\r\n\r\n######## response ########\r\n\r\n" + res.to_s
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
