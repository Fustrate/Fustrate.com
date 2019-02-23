import moment from 'moment';

import GameModal from './game_modal';

const pregameStatuses = ['Preview', 'Pre-Game', 'Warmup', 'Delayed Start', 'Scheduled'];
const inProgressStatuses = ['In Progress', 'Manager Challenge'];

const template = `
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
      <span class="outs"></span>
      <div class="runners">
        <div class="first"></div>
        <div class="second"></div>
        <div class="third"></div>
      </div>
    </div>
  </div>`;

class GameCard {
  constructor(game) {
    this.game = game;

    this.card = this.constructor.elementFromString(template);

    this.card.querySelector('.home-team').classList.add(this.game.teams.home.team.fileCode);
    this.card.querySelector('.away-team').classList.add(this.game.teams.away.team.fileCode);

    this.card.querySelector('.home-team .name').textContent = this.game.teams.home.team.abbreviation;
    this.card.querySelector('.away-team .name').textContent = this.game.teams.away.team.abbreviation;

    this.card.addEventListener('click', this.openGameModal.bind(this));

    this.refresh();
  }

  openGameModal() {
    if (!this.modal) {
      this.modal = new GameModal(this.game);
    }

    this.modal.open();
  }

  refreshRunners() {
    if (this.inProgress()) {
      this.card.querySelector('.runners').style.display = '';
    } else {
      this.card.querySelector('.runners').style.display = 'none';
    }

    if (!this.inProgress()) {
      return;
    }

    this.constructor.setBaseRunner(this.card.querySelector('.first'), this.game.linescore.offense.first);
    this.constructor.setBaseRunner(this.card.querySelector('.second'), this.game.linescore.offense.second);
    this.constructor.setBaseRunner(this.card.querySelector('.third'), this.game.linescore.offense.third);
  }

  static setBaseRunner(element, runner) {
    if (runner) {
      element.classList.add('runner');
      element.title = runner.fullName;
    } else {
      element.classList.remove('runner');
      element.title = '';
    }
  }

  refreshOuts() {
    if (this.inProgress()) {
      this.card.querySelector('.outs').style.display = '';
    } else {
      this.card.querySelector('.outs').style.display = 'none';
    }

    if (!this.inProgress()) {
      return;
    }

    const elements = [];

    const outSpan = '<span class="out"></span>';

    for (let i = this.game.linescore.outs; i < 3; i += 1) {
      elements.push(outSpan);
    }

    this.card.querySelector('.outs').innerHTML = elements.join('');
  }

  inProgress() {
    return inProgressStatuses.includes(this.game.status.detailedState);
  }

  pregame() {
    return pregameStatuses.includes(this.game.status.detailedState);
  }

  gameStatus() {
    const gameTime = moment(this.game.gameDate).format('h:mm');

    if (['Preview', 'Scheduled', 'Pre-Game'].includes(this.game.status.detailedState)) {
      return gameTime;
    }

    if (this.pregame()) {
      return `${gameTime} - ${this.game.status.detailedState}`;
    }

    if (!this.inProgress()) {
      return this.game.status.detailedState;
    }

    return `${this.game.linescore.inningState} ${this.game.linescore.currentInning}`;
  }

  refresh() {
    this.refreshOuts();
    this.refreshRunners();

    if (!this.pregame()) {
      this.card.querySelector('.home-team .runs').textContent = this.game.linescore.teams.home.runs;
      this.card.querySelector('.away-team .runs').textContent = this.game.linescore.teams.away.runs;
    }

    this.card.querySelector('.status').textContent = this.gameStatus();
  }

  update(game) {
    this.game = game;

    this.refresh();
  }

  static elementFromString(string) {
    const templateElement = document.createElement('template');

    templateElement.innerHTML = string.trim();

    return templateElement.content.firstChild;
  }
}

export default GameCard;
