require "test_helper"

describe Admin::CallbacksController do
  it "gets index" do
    get admin_callbacks_index_url
    must_respond_with :success
  end

  it "gets show" do
    get admin_callbacks_show_url
    must_respond_with :success
  end

  it "gets edit" do
    get admin_callbacks_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get admin_callbacks_update_url
    must_respond_with :success
  end
end
