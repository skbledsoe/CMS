ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app 
    Sinatra::Application
  end

  def setup 
    FileUtils.mkdir_p(data_path)
  end

  def teardown 
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end
  
  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_text_document
    create_document "history.txt", "HISTORY"

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "HISTORY"
  end

  def test_nonexist_document
    get "/notafile.txt"
    assert_equal 302, last_response.status
    assert_equal "notafile.txt does not exist.", session[:message]

    get "/"
    assert_nil session[:message]
  end

  def test_render_markdown
    create_document "about.md", "# Ruby is..."

    get "/about.md"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is.."
  end

  def test_edit_document
    create_document "changes.txt"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Edit content of changes.txt"
    assert_includes last_response.body, "<form"
  end

  def test_edit_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_update_document
    post "/changes.txt/edit", {content: "new content"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]
    
    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  def test_update_document_signed_out
    post "/changes.txt/edit"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "Add a new document"
    assert_includes last_response.body, '<input type="text"'
  end

  def test_new_document_form_signed_out
    get "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document
    post "/new", {filename: "history.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "history.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "history.txt"
    assert_nil session[:message]
  end

  def test_create_new_document_signed_out
    post "/new"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_create_new_document_without_name
    post "/new", {filename: ""}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end

  def test_create_new_document_without_extension
    post "/new", {filename: "hello"}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, "File extension must be"
  end

  def test_delete_document
    create_document "hello.txt"

    post "/hello.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "hello.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, 'href="/hello.txt"'
  end

  def test_delete_document_signed_out
    create_document "hello.txt"

    post "/hello.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_sign_in_form
    get "/signin"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Username:"
    assert_includes last_response.body, "Password:"
  end

  def test_sign_in_invalid_credentials
    post "/signin", { username: "user", password: "pass" }
    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
  end

  def test_successful_sign_in
    post "/signin", { username: "admin", password: "secret" }
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "admin", session[:username]

    get "/"
    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Sign Out"
  end

  def test_sign_out
    get "/", {}, {"rack.session" => {username: "admin"}}
    assert_includes last_response.body, "Signed in as admin"

    post "/signout"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]

    get last_response["Location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end
end

