require 'ostruct'

class HomeController < ApplicationController
  def index
    districts = CongressionalDistrict.leaderboard

    # Calculate average enrollment, ignoring nil or zero values
    enrollments = districts.map(&:high_school_enrollment).compact.reject(&:zero?)
    average_enrollment = enrollments.any? ? enrollments.sum.to_f / enrollments.size : 1.0 # Use 1.0 to avoid division by zero if all are zero/nil

    # Calculate average median income, ignoring nil or zero values
    incomes = districts.map(&:median_household_income).compact.reject(&:zero?)
    average_income = incomes.any? ? incomes.sum.to_f / incomes.size : 1.0

    # Calculate normalized scores for each district
    districts_with_scores = districts.map do |district|
      normalized_enrollment_score = if district.high_school_enrollment.to_i > 0 && average_enrollment > 0
                                     district.project_count.to_f * (average_enrollment / district.high_school_enrollment)
                                   else
                                     0
                                   end
      normalized_income_score = if district.median_household_income.to_i > 0 && average_income > 0
                                 district.project_count.to_f * (average_income / district.median_household_income)
                               else
                                 0
                               end

      OpenStruct.new(
        district: district,
        normalized_score: normalized_enrollment_score, # Keep existing name for ranking
        normalized_income_score: normalized_income_score
      )
    end

    # Sort districts by income-normalized score in descending order
    sorted_districts = districts_with_scores.sort_by { |d| -d.normalized_income_score }

    # Assign ranks based on income-normalized score, handling ties
    @ranked_districts = []
    last_score = nil
    current_rank = 0
    sorted_districts.each_with_index do |item, index|
      if item.normalized_income_score != last_score
        current_rank = index + 1
        last_score = item.normalized_income_score
      end
      item.normalized_rank = current_rank # Reuse the same attribute name for simplicity in view
      @ranked_districts << item
    end

    # The original @districts is no longer used directly by the view,
    # @ranked_districts contains all necessary info including the original district object.
  end
end
