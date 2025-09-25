class PagesController < ApplicationController
  allow_unauthenticated_access only: [ :privacy ]

  def privacy
    @hide_sidebar = true
  end
end
