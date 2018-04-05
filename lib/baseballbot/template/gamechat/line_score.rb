# frozen_string_literal: true

class Baseballbot
  module Template
    class Gamechat
      module LineScore
        BLANK_RHE = { 'runs' => 0, 'hits' => 0, 'errors' => 0 }.freeze

        def line_score
          [
            " |#{(1..(lines[0].count)).to_a.join('|')}|R|H|E",
            ":-:|#{(':-:|' * lines[0].count)}:-:|:-:|:-:",
            line_for_team(:away),
            line_for_team(:home)
          ].join "\n"
        end

        def line_score_status
          return game_data.dig('status', 'detailedState') unless live?

          return inning if outs == 3

          "#{runners}, #{outs} #{outs == 1 ? 'Out' : 'Outs'}, #{inning}"
        end

        def home_rhe
          return BLANK_RHE unless linescore&.dig('teams', 'home', 'runs')

          linescore.dig('teams', 'home')
        end

        def away_rhe
          return BLANK_RHE unless linescore&.dig('teams', 'away', 'runs')

          linescore.dig('teams', 'away')
        end

        protected

        def lines
          @lines ||= begin
            lines = [[nil] * 9, [nil] * 9]

            return lines unless started? && linescore&.dig('innings')

            linescore['innings'].each do |inning|
              if inning['away'] && !inning['away'].empty?
                lines[0][inning['num'] - 1] = inning.dig('away', 'runs')

                # In case of extra innings
                lines[1][inning['num'] - 1] = nil
              end

              next unless inning.dig('home', 'runs')

              lines[1][inning['num'] - 1] = inning.dig('home', 'runs')
            end

            lines
          end
        end

        def line_for_team(line_team)
          code = line_team == :home ? home_team.code : away_team.code
          line = line_team == :home ? lines[1] : lines[0]
          rhe = line_team == :home ? home_rhe : away_rhe

          "[#{code}](/#{code})|#{line.join('|')}|" \
            "#{bold rhe['runs']}|#{bold rhe['hits']}|#{bold rhe['errors']}"
        end
      end
    end
  end
end
