# frozen_string_literal: true

class Baseballbot
  module Template
    class Gamechat
      module Teams
        def away_name
          feed.dig('gameData', 'teams', 'away', 'teamName')
        end

        def away_code
          feed.dig('gameData', 'teams', 'away', 'abbreviation')
        end

        def home_name
          feed.dig('gameData', 'teams', 'home', 'teamName')
        end

        def home_code
          feed.dig('gameData', 'teams', 'home', 'abbreviation')
        end

        def away_record
          feed.dig('gameData', 'teams', 'away', 'record')
            &.values_at('wins', 'losses')
            &.join('-')
        end

        def home_record
          feed.dig('gameData', 'teams', 'home', 'record')
            &.values_at('wins', 'losses')
            &.join('-')
        end

        def away_id
          feed.dig('gameData', 'teams', 'away', 'teamID')
        end

        def home_id
          feed.dig('gameData', 'teams', 'home', 'teamID')
        end

        def opponent
          return @bot.gameday.team(home_code) if @subreddit.team&.id == away_id

          @bot.gameday.team(away_code)
        end

        def team
          @subreddit.team || @bot.gameday.team(home_code)
        end
      end
    end
  end
end
