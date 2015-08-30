class Baseballbot
  module Template
    class Sidebar
      module Standings
        STANDINGS = 'http://mlb.mlb.com/lookup/json/named.standings_schedule_' \
                    'date.bam?season=%Y&schedule_game_date.game_date=\'' \
                    '%Y/%m/%d\'&sit_code=\'h0\'&league_id=103&league_id=104' \
                    '&all_star_sw=\'N\'&version=2'

        def divisions
          @divisions ||= begin
            teams = {}

            load_teams_from_remote.each do |team|
              teams[team['team_abbrev'].to_sym] = parse_standings_row(team)
            end

            determine_wildcards teams

            sort_teams_into_divisions(teams).each do |_, teams_in_division|
              teams_in_division.sort_by! { |team| team[:sort_order] }
            end
          end
        end

        def standings
          divisions[@team.division.id]
        end

        def full_standings
          @full_standings ||= {
            nl: divisions[203].zip(divisions[205], divisions[204]),
            al: divisions[200].zip(divisions[202], divisions[201])
          }
        end

        def leagues
          @leagues ||= {
            nl: divisions[203] + divisions[204] + divisions[205],
            al: divisions[200] + divisions[201] + divisions[202]
          }
        end

        def draft_order
          @draft_order ||= divisions.values
                           .flatten(1)
                           .sort_by! { |team| team[:sort_order] }
                           .reverse
        end

        def wildcards_in_league(league)
          wildcard_order(league).reject { |team| team[:games_back] == 0 }
        end

        def wildcard_order(league)
          leagues[league].sort_by { |team| team[:wildcard_gb] }
        end

        def determine_wildcards(teams)
          determine_league_wildcards teams, [203, 204, 205]
          determine_league_wildcards teams, [200, 201, 202]
        end

        def determine_league_wildcards(teams, division_ids)
          eligible = teams_in_divisions(teams, division_ids)
                     .sort_by { |team| team[:wildcard_gb] }

          first_and_second_wildcards(eligible)
            .each_with_index do |teams_in_spot, position|
              teams_in_spot.each do |team|
                teams[team[:code].to_sym][:wildcard_position] = position + 1
              end
            end
        end

        def team_stats
          @team_stats ||= standings.find { |team| team[:code] == @team.code }
        end

        def [](stat)
          team_stats[stat]
        end

        protected

        # rubocop:disable Metrics/MethodLength
        def parse_standings_row(row)
          {
            code:           row['team_abbrev'],
            wins:           row['w'].to_i,
            losses:         row['l'].to_i,
            games_back:     row['gb'].to_f,
            percent:        row['pct'].to_f,
            last_ten:       row['last_ten'],
            streak:         row['streak'],
            run_diff:       row['runs'].to_i - row['opp_runs'].to_i,
            home_record:    row['home'].split('-'),
            road_record:    row['away'].split('-'),
            interleague:    row['interleague'],
            wildcard:       row['gb_wildcard'],
            wildcard_gb:    wildcard(row['gb_wildcard']),
            elim:           row['elim'],
            elim_wildcard:  row['elim_wildcard'],
            division_champ: %w(y z).include?(row['playoffs_flag_mlb']),
            wildcard_champ: %w(w x).include?(row['playoffs_flag_mlb']),
            division_id:    row['division_id'].to_i,
            team:           @bot.gameday.team(row['team_abbrev']),
            subreddit:      subreddit(row['team_abbrev'])
          }.tap do |team|
            # Used for sorting teams in the standings. Lowest losing %, most
            # wins, least losses, and then fall back to three letter code
            team[:sort_order] = [
              1.0 - team[:percent],
              162 - team[:wins],
              team[:losses],
              team[:code]
            ]
          end
        end
        # rubocop:enable Metrics/MethodLength

        def sort_teams_into_divisions(teams)
          Hash.new { |hash, key| hash[key] = [] }.tap do |divisions|
            teams.each { |_, team| divisions[team[:division_id]] << team }
          end
        end

        def teams_in_divisions(teams, ids)
          teams.values.keep_if { |team| ids.include?(team[:division_id]) }
        end

        def first_and_second_wildcards(eligible)
          eligible
            .reject { |team| team[:wildcard_gb] > eligible[4][:wildcard_gb] }
            .reject { |team| team[:games_back] == 0 }
            .partition { |team| team[:wildcard_gb] == 0 }
        end

        def load_teams_from_remote
          # Don't ask me, MLB started acting stupid one day. Going back 4 hours
          # seems to fix the problem.
          filename = (Time.now - 4 * 3600).strftime STANDINGS

          JSON.parse(open(filename).read)['standings_schedule_date'] \
            ['standings_all_date_rptr']['standings_all_date']
            .flat_map { |league| league['queryResults']['row'] }
        end
      end
    end
  end
end
