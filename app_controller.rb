require 'sinatra/base'
require 'sinatra/activerecord'
require './models/model_interface'
require './models/user'
require 'json'
require './lib/ip_filter'

class AppController < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  helpers Sinatra::OpenApiIpFilter

  set :controllers, %w[users]
  set :environment, :development
  set :max_records, 40
  set :default_order, 'id desc'

  configure :development do
    set :database, { adapter: 'sqlite3', database: 'db/development.sqlite3' }
    set :authentication, false
    set :filter_ip, false
  end

  configure :production do
    set :database, { adapter: 'sqlite3', database: 'db/development.sqlite3' }
    enable :authentication
    set :filter_ip, true
  end

  if settings.authentication?
    use Rack::Auth::Basic, "Restricted Area" do |username, password|
      user = User.find_by_name(username)
      if user
        set :current_user, user
        user.password == password
      else
        false
      end #if
    end 
  end #if

  helpers do
    def model
      Module.const_get(settings.model) rescue 'no model set with controller'
    end

    def json_params
      JSON.parse(request.env["rack.input"].read)
    end

    def json_status(code, reason)
      status code
      {
        :status => code,
        :reason => reason
      }.to_json
    end

  end

  before '/' do
    limit = params.delete('limit') 
    @limit = limit and limit.to_i < settings.max_records ? limit : settings.max_records
    order = params.delete('order')
    @order = order ? order : settings.default_order
    if settings.filter_ip? and settings.current_user
      json_status(403, 'not allowed ip') and halt unless filter_ip(settings.current_user.allowed_ip)
    end
  end

  get '/' do
    content_type :json
    records = []
    model.all.limit(@limit).order(@order).each_with_index do |record|
      records << record.json_output
    end #each
    '[' + records.join(',') + ']'
  end

  post '/' do
    content_type :json
    json = json_params
    if result = model.send(:create, json)
      result.json_output
    else 
      json_status(404, 'failed to create')
    end #if
  end

  put '/' do
    content_type :json
    json = json_params
    id = json.delete("id")
    json_status(404, 'id is required') unless id
    record = model.send(:find, id) rescue nil
    result = nil
    result = record.update_attributes(json) if record
    if result
      json_status(200, 'successfully update')
    else
      json_status(404, 'faild to update')
    end #if
  end

  delete '/' do
    content_type :json
    json = json_params
    id = json.delete("id")
    json_status(404, 'id is required') unless id
    record = model.send(:find, id) rescue nil
    puts id
    puts record
    result = nil
    result = record.destroy if record
    if result
      json_status(200, 'successfully delete')
    else
      json_status(404, 'faild to delete')
    end #if
  end 

end

