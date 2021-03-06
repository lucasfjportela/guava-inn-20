class Room < ApplicationRecord
  has_many :reservations

  before_destroy :check_existence_of_reservations, if: -> { reservations.any? }

  validates :code, presence: true, uniqueness: true, length: { minimum: 3, maximum: 9 }
  validates :capacity, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
  validate :changes_on_capacity, if: -> { reservations.any? }, on: :update

  after_find :calculate_occupancy_rates

  attr_reader :weekly_occupancy_rate, :monthly_occupancy_rate

  scope :with_capacity, ->(number_of_guests) {
    where('capacity >= ?', number_of_guests)
  }

  scope :not_available_at, ->(start_date, end_date) {
    joins(:reservations).where('start_date < ? AND end_date > ?', end_date, start_date)
  }

  def occupancy_rate_calculation(next_days)
    return 0 if reservations.blank?
    ###
    # Using DateTime instead Date to work with local time zone system
    period_start_date = (DateTime.now + 1.day).to_date
    period_end_date = (next_days.days.from_now).to_date
    selected_period = (period_start_date..period_end_date).to_a

    days_with_reservation = 0
    reservations.each do |reservation|
      ###
      # Skipping rooms from past periods than selected period
      next if reservation.end_date < period_start_date
      ###
      # Note that on each reservation case the end_date shouldn't be considered
      # as a 'occupied day' since the end_date ends at 12:00 PM and the room is
      # free after this. So, we don't count with the last day of reservation.
      reservation_period = (reservation.start_date..(reservation.end_date - 1.day)).to_a
      ###
      # Using the bitwise AND operator to get the intersection between period
      # range and each reservation date range.
      days_with_reservation += (selected_period & reservation_period).count
    end

    ((days_with_reservation.to_f / next_days) * 100).round
  end

  private

  def calculate_occupancy_rates
    @weekly_occupancy_rate = occupancy_rate_calculation(7)
    @monthly_occupancy_rate = occupancy_rate_calculation(30)
  end

  def changes_on_capacity
    if reservations.where('number_of_guests > ?', capacity).any?
      errors.add(
        :capacity,
        :invalid_capacity,
        message: "couldn't be updated because the room has ongoing
          reservations with more than #{capacity} guests."
      )
    end
  end

  def check_existence_of_reservations
    throw(:abort)
  end
end
