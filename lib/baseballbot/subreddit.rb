# frozen_string_literal: true
require_relative 'template/base'
require_relative 'template/gamechat'
require_relative 'template/sidebar'

class Baseballbot
  class Subreddit
    attr_reader :account, :name, :team, :time, :code

    def initialize(bot:, id:, name:, code:, account:, options: {})
      @bot = bot
      @id = id
      @name = name
      @account = account
      @submissions = {}
      @options = options
      @code = code

      @time = begin
        TZInfo::Timezone.get options['timezone']
      rescue TZInfo::InvalidTimezoneIdentifier
        TZInfo::Timezone.get 'America/Los_Angeles'
      end

      @team = @bot.gameday.team(@code) if @code
    end

    # !@group Game Chats

    def post_gamechat(id:, gid:, title:)
      @bot.use_account(@account.name)

      template = gamechat_template(gid: gid, title: title)

      submission = submit title: template.title, text: template.result

      # Mark as posted right away so that it won't post again
      change_gamechat_status id, submission, 'Posted'

      raw_markdown = CGI.unescapeHTML(submission.selftext)

      post.edit raw_markdown.gsub('#ID#', submission.id)

      @bot.redis.hset(template.game.gid, @name.downcase, submission.id)

      post_process_submission(
        submission,
        sticky: sticky_gamechats?,
        sort: 'new',
        flair: @options.dig('gamechats', 'flair')
      )

      submission
    end

    # Update a gamechat - also starts the "game over" process if necessary
    #
    # @param id [String] The baseballbot id of the gamechat
    # @param gid [String] The mlb gid of the game
    # @param post_id [String] The reddit id of the post to update
    #
    # @return [Boolean] to indicate if the game is over or postponed
    def update_gamechat(id:, gid:, post_id:)
      @bot.use_account(@account.name)

      template = gamechat_update_template(gid: gid, post_id: post_id)
      submission = load_submission(id: post_id)
      game_over = template.game.over? || template.game.postponed?

      edit(
        id: post_id,
        body: template.replace_in(CGI.unescapeHTML(submission.selftext))
      )

      change_gamechat_status id, submission, game_over ? 'Over' : 'Posted'

      end_gamechat(id, submission, gid) if game_over

      game_over
    end

    def end_gamechat(id, submission, gid)
      change_gamechat_status id, submission, 'Over'

      post_process_submission(
        submission,
        sticky: sticky_gamechats? ? false : nil
      )

      post_postgame(gid: gid)
    end

    # !@endgroup

    # !@group Pre Game Chats

    def post_pregame(id:, gid:)
      return unless @options.dig('pregame', 'enabled')

      @bot.use_account(@account.name)

      template = pregame_template(gid: gid)

      submission = submit title: template.title, text: template.result

      change_gamechat_status id, submission, 'Pregame'

      post_process_submission(
        submission,
        sticky: sticky_gamechats?,
        flair: @options.dig('pregame', 'flair')
      )

      submission
    end

    # !@endgroup

    # !@group Post Game Chats

    def post_postgame(gid:)
      return unless @options.dig('postgame', 'enabled')

      @bot.use_account(@account.name)

      template = postgame_template(gid: gid)

      submission = submit title: template.title, text: template.result

      post_process_submission(
        submission,
        sticky: sticky_gamechats?,
        flair: @options.dig('postgame', 'flair')
      )
    end

    # !@endgroup

    # --------------------------------------------------------------------------
    # Miscellaneous
    # --------------------------------------------------------------------------

    def sticky_gamechats?
      @options.dig('gamechats', 'sticky') != false
    end

    def generate_sidebar
      sidebar_template.replace_in current_sidebar
    end

    def current_sidebar
      raise Baseballbot::Error::NoSidebarText unless settings[:description]

      CGI.unescapeHTML settings[:description]
    end

    def change_gamechat_status(id, submission, status)
      fields = ['status = $2', 'updated_at = $3']
      fields.concat ['post_id = $4', 'title = $5'] if submission

      @db.exec_params(
        "UPDATE gamechats SET #{fields.join(', ')} WHERE id = $1",
        [
          id,
          status,
          Time.now,
          submission&.id,
          submission&.title
        ].compact
      )
    end

    def subreddit
      @subreddit ||= @bot.session.subreddit(@name)
    end

    def settings
      @settings ||= subreddit.settings
    end

    # Update settings for the current subreddit
    #
    # @param new_settings [Hash] new settings to apply to the subreddit
    def update(new_settings = {})
      @bot.use_account(@account.name)

      response = subreddit.modify_settings(new_settings)

      log_errors response.body.dig(:json, :errors), new_settings
    end

    # Submit a post to reddit in the current subreddit
    #
    # @param title [String] the title of the submission to create
    # @param text [String] the markdown body of the submission to create
    #
    # @return [Redd::Models::Submission] the successfully created submission
    #
    # @todo Restore ability to pass captcha
    def submit(title:, text:)
      @bot.use_account(@account.name)

      subreddit.submit(title, text: text, sendreplies: false)
    end

    def edit(id:, body: nil)
      @bot.use_account(@account.name)

      load_submission(id: id).edit(body)
    end

    # Load a submission from reddit by its id
    #
    # @param id [String] an id to load
    #
    # @return [Redd::Models::Submission] the submission, if found
    #
    # @raise [RuntimeError] if a submission with this id does not exist
    def load_submission(id:)
      return @submissions[id] if @submissions[id]

      @bot.use_account(@account.name)

      submissions = @bot.session.from_ids "t3_#{id}"

      raise "Unable to load post #{id}." unless submissions&.first

      @submissions[id] = submissions.first
    end

    protected

    def post_process_submission(submission, sticky: false, sort: '', flair: nil)
      if submission.stickied
        submission.remove_sticky if sticky == false
      elsif sticky
        submission.make_sticky
      end

      submission.set_suggested_sort(sort) unless sort == ''

      subreddit.set_flair_template(submission, flair) if flair
    end

    def sidebar_template
      body, = template_for('sidebar')

      Template::Sidebar.new body: body, bot: @bot, subreddit: self
    end

    def gamechat_template(gid:, title:)
      body, default_title = template_for('gamechat')

      title = title && !title.empty? ? title : default_title

      Template::Gamechat.new body: body,
                             bot: @bot,
                             subreddit: self,
                             gid: gid,
                             title: title
    end

    def gamechat_update_template(gid:, post_id:)
      body, = template_for('gamechat_update')

      Template::Gamechat.new body: body,
                             bot: @bot,
                             subreddit: self,
                             gid: gid,
                             post_id: post_id
    end

    def pregame_template(gid:)
      body, title = template_for('pregame')

      Template::Gamechat.new body: body,
                             bot: @bot,
                             subreddit: self,
                             gid: gid,
                             title: title
    end

    def postgame_template(gid:)
      body, title = template_for('postgame')

      Template::Gamechat.new body: body,
                             bot: @bot,
                             subreddit: self,
                             gid: gid,
                             title: title
    end

    def template_for(type)
      result = @bot.db.exec_params(
        "SELECT body, title
        FROM templates
        WHERE subreddit_id = $1 AND type = $2",
        [@id, type]
      )

      raise "/r/#{@name} does not have a #{type} template." if result.count < 1

      [result[0]['body'], result[0]['title']]
    end

    # --------------------------------------------------------------------------
    # Logging
    # --------------------------------------------------------------------------

    def log_errors(errors, new_settings)
      return unless errors&.count&.positive?

      errors.each do |error|
        log "#{error[0]}: #{error[1]} (#{error[2]})"

        next unless error[0] == 'TOO_LONG' && error[1] =~ /max: \d+/

        # TODO: Message the moderators of the subreddit to tell them their
        # sidebar is X characters too long.
        puts "New length is #{new_settings[error[2].to_sym].length}"
      end
    end

    # TODO: Make this an actual logger, so we can log to something different
    def log(message)
      puts Time.now.strftime "[%Y-%m-%d %H:%M:%S] #{@name}: #{message}"
    end
  end
end
