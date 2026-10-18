class PositionsController < ApplicationController
  def index
    render json: Position.order(:account, :commodity).pluck(:account, :commodity, :quantity).map { |account, commodity, quantity|
      {account: account, commodity: commodity, quantity: quantity}
    }
  end

  def processed
    render json: {count: ProcessedExecution.count}
  end
end
