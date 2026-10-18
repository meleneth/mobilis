class Position < ApplicationRecord
  validates :account, :commodity, presence: true
end
