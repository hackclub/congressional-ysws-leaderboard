class HomeController < ApplicationController
  def index
    @districts = CongressionalDistrict.leaderboard
  end
end
