class Gameday.GameCard
  @gameCardTemplate: $ '''
    <div class="game-card">
      <div class="away-team">
        <div class="runs"></div>
        <div class="name"></div>
      </div>
      <div class="home-team">
        <div class="name"></div>
        <div class="runs"></div>
      </div>
      <div class="game-info">
        <span class="status"></span>
      </div>
    </div>'''

  @runnersTemplate: $ '''
    <div class="runners">
      <div class="first"></div>
      <div class="second"></div>
      <div class="third"></div>
    </div>'''

  @inProgressStatuses: ['In Progress', 'Manager Challenge']

  constructor: (@game) ->
    @card = @constructor.gameCardTemplate.clone()

    @card
      .attr(id: @game.gameday_link)
      .data(gameCard: @)

    $('.home-team', @card).addClass @game.home_file_code
    $('.away-team', @card).addClass @game.away_file_code

    $('.home-team .name', @card).text @game.home_name_abbrev
    $('.away-team .name', @card).text @game.away_name_abbrev

  # 0: Bases empty
  # 1: Runner on 1st
  # 2: Runner on 2nd
  # 3: Runner on 3rd
  # 4: Runners on 1st and 2nd
  # 5: Runners on 1st and 3rd
  # 6: Runners on 2nd and 3rd
  # 7: Bases loaded
  runners: =>
    return unless @game.status is 'In Progress'

    index = parseInt @game.runner_on_base_status, 10

    unless @runnersDiv
      @runnersDiv = @constructor.runnersTemplate.clone()
      $('.game-info', @card).append @runnersDiv

    $('.first', @runnersDiv).toggleClass 'runner', (index in [1, 4, 5, 7])
    $('.second', @runnersDiv).toggleClass 'runner', (index in [2, 4, 6, 7])
    $('.third', @runnersDiv).toggleClass 'runner', (index in [3, 5, 6, 7])

  inProgress: =>
    @game.status in @constructor.inProgressStatuses

  gameStatus: =>
    return @game.time if @game.status is 'Preview'

    return @game.status if @game.status in ['Pre-Game', 'Warmup', 'Delayed']

    return @game.status if not @inProgress()

    sides = if @game.outs is '3' then ['Mid', 'End'] else ['Top', 'Bot']
    side = if @game.top_inning is 'Y' then sides[0] else sides[1]

    "#{side} #{@game.inning}"

  refreshInfo: =>
    @runners()

    $('.home-team .runs', @card).text @game.home_team_runs
    $('.away-team .runs', @card).text @game.away_team_runs

    $('.status', @card).text @gameStatus(@game)

  render: =>
    @refreshInfo()

    @card

  update: (@game) ->
    @refreshInfo()
