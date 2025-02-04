# frozen_string_literal: true

class RoundResult
  attr_accessor :id, :current_player, :opponent, :rank, :card_drawn, :book_rank, :winners, :messages

  def initialize(id:, current_player:, opponent:, rank:, card_drawn:, book_rank:, winners:)
    @id = id
    @current_player = current_player
    @opponent = opponent
    @rank = rank
    @card_drawn = card_drawn
    @book_rank = book_rank
    @winners = winners
  end

  def self.from_json(round_result_data)
    id = round_result_data['id'].to_i
    current_player = Player.from_json(round_result_data['current_player'])
    winners = round_result_data['winners']&.map { |winner_data| Player.from_json(winner_data) } || []
    opponent = Player.from_json(round_result_data['opponent'])
    rank = round_result_data['rank']
    book_rank = round_result_data['book_rank']
    card_drawn = Card.from_json(round_result_data['card_drawn']) unless round_result_data['card_drawn'].nil?
    RoundResult.new(id:, current_player:, opponent:, rank:, card_drawn:, book_rank:, winners:)
  end

  # TODO: messages.send("#{context}_messages")
  def messages_for(context)
    round_message = RoundMessage.new(current_player:, opponent:, rank:, card_drawn:, book_rank:, winners:)

    case context
    when :player
      round_message.generate_player_messages
    when :opponent
      round_message.generate_opponent_messages
    when :others
      round_message.generate_others_messages
    end
  end
end
