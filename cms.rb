require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def session_details
  session.inspect
end

def render_file(path)
  content = File.read(path)

  case File.extname(path)
  when '.md'
    erb render_markdown(content)
  when '.txt'
    content_type "text/plain"
    content
  end
end

def name_error?(filename)
  if filename.empty?
    session[:message] = "A name is required."
  elsif !['.md', '.txt'].include?(File.extname(filename))
    session[:message] = "File extension must be '.txt' or '.md'."
  end
end

def signed_in?
  session[:username]
end

def require_signed_in_user
  unless signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def load_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

configure do
  enable :sessions
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/new" do
  require_signed_in_user

  filename = params[:filename].to_s

  if name_error?(filename)
    status 422
    erb :new
  else
    File.write(File.join(data_path, filename), "")
    session[:message] = "#{filename} was created."
    redirect "/"
  end

end

get "/signin" do
  erb :signin
end

post "/signin" do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    status 422
    session[:message] = "Invalid Credentials"
    erb :signin
  end
end

post "/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  path = File.join(data_path, params[:filename])

  if File.file?(path)
    render_file(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user

  path = File.join(data_path, params[:filename])
  @content = File.read(path)

  erb :edit
end

post "/:filename/edit" do
  require_signed_in_user

  path = File.join(data_path, params[:filename])
  
  File.write(path, params[:content])
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

post "/:filename/delete" do
  require_signed_in_user

  path = File.join(data_path, params[:filename])

  File.delete(path)
  session[:message] = "#{params[:filename]} has been deleted."
  redirect "/"
end