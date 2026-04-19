require "test_helper"

class AutoUploadsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get auto_uploads_index_url
    assert_response :success
  end
end
