require_relative 'deck'

class GoFish
  class InvalidRank < StandardError; end
  class InvalidTurn < StandardError; end

  STARTING_HAND_SIZE = 5

  attr_accessor :deck, :current_player, :players, :stay_turn, :winners, :round_results, :card_drawn

  def initialize(players:, deck: Deck.new, current_player: players.first, winners: [], round_results: [])
    @players = players
    @deck = deck
    @current_player = current_player
    @stay_turn = false
    @winners = winners
    @round_results = round_results
    @card_drawn = nil
  end

  def deal!
    deck.shuffle!

    STARTING_HAND_SIZE.times do
      players.each { |player| player.add_to_hand(deck.deal) }
    end
  end

  def next_player
    self.current_player = players[(players.index(current_player) + 1) % players.size]
  end

  def play_round!(opponent, rank)
    raise InvalidTurn unless winners.empty?
    raise InvalidRank unless current_player.hand_has_rank?(rank)

    if opponent.hand_has_rank?(rank)
      take_cards(opponent, rank)
    else
      go_fish(rank)
    end
    finalize_turn(opponent, rank)
  end

  def self.dump(object)
    object.as_json
  end

  def self.load(payload)
    return if payload.nil?

    from_json(payload)
  end

  def self.from_json(payload)
    players = payload['players'].map { |player_data| Player.from_json(player_data) }
    deck = Deck.from_json(payload['deck'])
    current_player = players.detect { |player| player.user_id == payload['current_player']['user_id'] }
    winners = payload['winners']&.map { |winner_data| players.detect { |player| player.user_id == winner_data['user_id'] } } || []
    round_results = payload['round_results']&.map { |round_result_data| RoundResult.from_json(round_result_data) }
    GoFish.new(players:, deck:, current_player:, winners:, round_results:)
  end

  private

  def take_cards(opponent, rank)
    cards_to_move = opponent.remove_by_rank(rank)
    current_player.add_to_hand(cards_to_move)
    self.stay_turn = true
  end

  def go_fish(rank)
    return if deck.cards.empty?

    self.card_drawn = deck.deal
    current_player.add_to_hand([card_drawn])
    self.stay_turn = card_drawn.rank == rank
  end

  def finalize_turn(opponent, rank)
    book_rank = create_book_if_possible(current_player)
    game_over
    draw_if_empty
    create_results(opponent, rank, book_rank)
    next_player unless stay_turn
    skip_turns
  end

  def create_book_if_possible(player)
    ranks = player.hand.map(&:rank)
    book_rank = ranks.find { |rank| ranks.count(rank) == 4 }
    return nil unless book_rank

    book_cards = player.remove_by_rank(book_rank)
    new_book = Book.new(book_cards)
    player.books << new_book
    new_book.cards.first.rank
  end

  def create_results(opponent, rank, book_rank = nil)
    round_results.unshift(RoundResult.new(id: (round_results.length + 1), current_player:, opponent:, rank:, card_drawn:, book_rank:, winners:))
  end

  def game_over
    return unless deck.cards.empty? && players.all? { |player| player.hand.empty? }

    max_books = players.map { |player| player.books.size }.max
    potential_winners = players.select { |player| player.books.size == max_books }

    if potential_winners.size > 1
      max_value = potential_winners.map(&:book_score).max
      potential_winners = potential_winners.select { |player| player.book_score == max_value }
    end

    self.winners = potential_winners
  end

  def draw_if_empty
    players.each do |player|
      if player.hand.empty? && deck.cards.any?
        draw_count = [STARTING_HAND_SIZE, deck.cards.size].min
        draw_count.times { player.add_to_hand(deck.deal) }
      end
    end
  end

  def skip_turns
    return if winners.any?

    next_player until current_player.hand.any?
  end
end
