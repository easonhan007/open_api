require 'sinatra/base'
require 'sinatra/activerecord'
require './models/app_model'
require './models/user'
require 'json'
require './lib/ip_filter'
require './lib/query_args'

class AppController < Sinatra::Base
  register Sinatra::ActiveRecordExtension
  register Sinatra::OpenApiQueryArgs
  helpers Sinatra::OpenApiIpFilter

  set :controllers, %w[users]
  set :environment, :development

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

    def contain_all_required_fields?(field_type)
      return true if (fields = model.send(field_type)).empty?
      fields.all? { |field| params.has_key?(field) and !params[field].empty? }
    end

  end

  before '/' do
    content_type :json

    if settings.filter_ip? and settings.current_user
      halt(403, 'your ip is not allowed'.to_json) unless filter_ip(settings.current_user.allowed_ip)
    end

  end

  get '/' do
    halt(404, 'some fields required'.to_json) unless contain_all_required_fields?(:get_required_fields)
    records = []
    model.where(params).limit(@limit).offset(@offset).order(@order).to_json
  end

  post '/' do
    json = json_params
    if result = model.send(:create, json)
      result.to_json
    else 
      json_status(404, 'failed to create')
    end #if
  end

  put '/' do
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
    result = nil
    result = record.destroy if record
    if result
      json_status(200, 'successfully delete')
    else
      json_status(404, 'faild to delete')
    end #if
  end 

end

