# frozen_string_literal: true

class GameThreadsController < ApplicationController
  before_action :require_login, except: %i[index show]
  before_action :load_game_thread, except: %i[index new create]

  def index
    respond_to do |format|
      format.html
      format.json do
        @game_threads = GameThreads::LoadPage.call
      end
    end
  end

  def show
  end

  def new
    @game_thread = GameThread.new
  end

  def create
    @game_thread = GameThread::Create.call

    render :show, status: :created
  end

  def edit
  end

  def update
  end

  def destroy
  end

  protected

  def load_game_thread
    @game_thread = GameThread.find params[:id]
  end
end
