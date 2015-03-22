class Baseballbot
  module Template
    class Gamechat < Base
      attr_reader :game, :title

      def initialize(body:, bot:, subreddit:, gid:, title:)
        super(body: body, bot: bot)

        @subreddit = subreddit
        @team = subreddit.team
        @game = bot.gameday.game gid
        @title = format_title title
      end

      def inspect
        %(#<Baseballbot::Template::Gamechat @team="#{@team.name}" @gid="#{@game.gid}">)
      end

      def player_url(id)
        "http://mlb.mlb.com/team/player.jsp?player_id=#{id}"
      end

      def pitcher_line(node)
        name = "#{node.xpath('useName').text} #{node.xpath('lastName').text}"

        format '[%{name}](%{url}) (%{wins}-%{losses}, %{era} ERA)',
               name: name,
               url: player_url(node.xpath('player_id').text),
               wins: node.xpath('wins').text,
               losses: node.xpath('losses').text,
               era: node.xpath('era').text
      end

      def home?
        @is_home ||= @game.home_team.code == @team.code
      end

      def home
        unless @game.started?
          {
            runs: 0,
            hits: 0,
            errors: 0
          }
        end

        rhe = @game.boxscore.at_xpath '//boxscore/linescore'

        {
          runs: rhe['home_team_runs'].to_i,
          hits: rhe['home_team_hits'].to_i,
          errors: rhe['home_team_errors'].to_i
        }
      end

      def away
        unless @game.started?
          {
            runs: 0,
            hits: 0,
            errors: 0
          }
        end

        rhe = @game.boxscore.at_xpath '//boxscore/linescore'

        {
          runs: rhe['away_team_runs'].to_i,
          hits: rhe['away_team_hits'].to_i,
          errors: rhe['away_team_errors'].to_i
        }
      end

      def lines
        return [[nil] * 9] * 2 unless @game.started?

        lines = [[nil] * 9, [nil] * 9]

        bs = @game.boxscore

        bs.xpath('//boxscore/linescore/inning_line_score').each do |inning|
          if inning['away'] && !inning['away'].empty?
            lines[0][inning['inning'].to_i - 1] = inning['away']

            # In case of extra innings
            lines[1][inning['inning'].to_i - 1] = nil
          end

          if inning['home'] && !inning['home'].empty?
            lines[1][inning['inning'].to_i - 1] = inning['home']
          end
        end

        lines
      end

      def batters
        if @game.started?
          bs = @game.boxscore

          home_batters = bs.xpath('//boxscore/batting[@team_flag="home"]/batter').to_a
          away_batters = bs.xpath('//boxscore/batting[@team_flag="away"]/batter').to_a

          batter_rows = [home_batters.length, away_batters.length].max

          home_batters += [nil] * (batter_rows - home_batters.length)
          away_batters += [nil] * (batter_rows - away_batters.length)

          home_batters.zip away_batters
        else
          []
        end
      end

      def pitchers
        if @game.started?
          bs = @game.boxscore

          home_pitchers = bs.xpath('//boxscore/pitching[@team_flag="home"]/pitcher').to_a
          away_pitchers = bs.xpath('//boxscore/pitching[@team_flag="away"]/pitcher').to_a

          pitcher_rows = [home_pitchers.length, away_pitchers.length].max

          home_pitchers += [nil] * (pitcher_rows - home_pitchers.length)
          away_pitchers += [nil] * (pitcher_rows - away_pitchers.length)

          home_pitchers.zip away_pitchers
        else
          []
        end
      end

      def scoring_plays
        scoring_plays = []

        data = Nokogiri::XML open Time.now.strftime(
          'http://gd2.mlb.com/components/game/mlb/year_%Y/month_%m/day_%d/' \
          "gid_#{@game.gid}/inning/inning_Scores.xml"
        )

        data.xpath('//scores/score').each do |play|
          score = if play['top_inning'] == 'Y'
                    "#{play['home']}-#{bold play['away']}"
                  else
                    "#{bold play['home']}-#{play['away']}"
                  end

          scoring_plays << {
            side:   play['top_inning'] == 'Y' ? 'T' : 'B',
            inning: play['inn'],
            event:  play.at_xpath('*[@des and @score="T"]')['des'],
            score:  score
          }
        end

        scoring_plays
      end

      def innings
        return 'Postponed' if @game.postponed?

        return 'Final' if @game.over?

        if @game.in_progress?
          return @game.inning[1] + ' of the ' + @game.inning[0].to_i.ordinalize
        end

        @game.status
      rescue
        @game.status
      end

      def outs
        if game.linescore.at_xpath('//game/@outs')
          returngame.linescore.xpath('//game/@outs').text.to_i
        end

        ''
      end

      def runners
        rob = game.linescore.at_xpath '//game/@runner_on_base_status'

        if rob
          return [
            'Bases empty',
            'Runner on first',
            'Runner on second',
            'Runner on third',
            'First and second',
            'First and third',
            'Second and third',
            'Bases loaded',
          ][rob.text.to_i]
        end

        ''
      end

      # I'm Bill James, bitch!
      # http://en.wikipedia.org/wiki/Game_score
      def game_score(pitcher)
        outs = pitcher['out'].to_i
        earned = pitcher['er'].to_i
        unearned = pitcher['r'].to_i - earned

        50 + outs + (2 * [(outs / 3 - 4).floor, 0].max) + pitcher['so'].to_i -
          (2 * pitcher['h'].to_i) - (4 * earned) - (2 * unearned) -
          pitcher['bb'].to_i
      end

      protected

      def format_title(title)
        title = Time.now.strftime title

        format title,
               home_city: @game.home_team.city,
               home_name: @game.home_team.name,
               home_record: @game.home_record.join('-'),
               home_pitcher: @game.linescore.xpath(
                 '//game/home_probable_pitcher/@last_name'
               ).text,
               away_city: @game.away_team.city,
               away_name: @game.away_team.name,
               away_record: @game.away_record.join('-'),
               away_pitcher: @game.linescore.xpath(
                 '//game/away_probable_pitcher/@last_name'
               ).text,
               start_time: home? ? @game.home_start_time : @game.away_start_time
      end
    end
  end
end
