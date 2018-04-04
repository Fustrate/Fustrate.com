# frozen_string_literal: true

require 'chronic'
require 'erb'
require 'honeybadger/ruby'
require 'logger'
require 'mlb_stats_api'
require 'open-uri'
require 'pg'
require 'redd'
require 'redis'
require 'tzinfo'

require_relative 'baseballbot/error'
require_relative 'baseballbot/subreddit'
require_relative 'baseballbot/account'

require_relative 'baseballbot/accounts'
require_relative 'baseballbot/gamechats'
require_relative 'baseballbot/pregames'
require_relative 'baseballbot/sidebars'
require_relative 'baseballbot/subreddits'

require_relative 'baseballbot/template/base'
require_relative 'baseballbot/template/gamechat'
require_relative 'baseballbot/template/sidebar'

class Baseballbot
  include Accounts
  include Gamechats
  include Pregames
  include Sidebars
  include Subreddits

  attr_reader :db, :api, :client, :session, :redis, :logger

  def initialize(options = {})
    @client = Redd::APIClient.new(
      Redd::AuthStrategies::Web.new(
        client_id: options[:reddit][:client_id],
        secret: options[:reddit][:secret],
        redirect_uri: options[:reddit][:redirect_uri],
        user_agent: options[:reddit][:user_agent]
      ),
      limit_time: 0
    )
    @session = Redd::Models::Session.new(@client)

    @db = PG::Connection.new options[:db]
    @redis = Redis.new

    @logger = options[:logger] || Logger.new(STDOUT)

    @api = MLBStatsAPI::Client.new(logger: @logger, cache: @redis)
  end

  def inspect
    %(#<Baseballbot>)
  end

  def accounts
    @accounts ||= load_accounts
  end

  def subreddits
    @subreddits ||= load_subreddits
  end
end
