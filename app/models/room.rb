class Room < ApplicationRecord
  has_many :reservations, dependent: :restrict_with_exception

  validates :code, presence: true
  validates :capacity, presence: true,
  validates :code, uniqueness: true
  validates :capacity, numericality: { greater_than: 0, less_than_or_equal_to: 10 }
end