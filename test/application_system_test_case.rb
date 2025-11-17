require "test_helper"
require "capybara/rails"
Capybara.default_max_wait_time = 5

Capybara.register_driver :chrome_headless_ci do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless=new")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :chrome_headless_ci

  setup do
    login_as_admin
  end

  private
    def login_as_admin
      visit new_session_path
      fill_in "email", with: users(:one).email
      fill_in "password", with: "password"
      click_button "Ingresar"
    end
end
