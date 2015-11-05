var _ = require('lodash');
var React = require('react');
var Router = require('react-router');
var DefaultRoute = Router.DefaultRoute;
var Link = Router.Link;
var Route = Router.Route;
var RouteHandler = Router.RouteHandler;
var api = require('../api');

var CommentForm = require('./comment_form.js');
var Highlight = require('./highlight.js');
var Loading = require('../loading');

var ScoreForm = React.createClass({
    getInitialState: function() {
      return {
        score_hash: {}
      };
    },

    componentDidMount: function() {
      this.setTemplateText();
    },

    setTemplateText: function() {
      var data = {
        action: 'template',
        report: this.props.report,
      };

      api.get({
        api: 'score',
        data: data
      }).done(function(template) {
        this.setState({
          score_hash: JSON.parse(template.replace(/=>/g, ': '))
        });
      }.bind(this));
    },

    synchronizeWithTestResult: function() {
      var data = {
        user: this.props.token,
        report: this.props.report,
      };
      api.get({
        api: 'user',
        data: _.assign({ type: 'status' }, data)
      }).done(function(u) {
        if (_.isUndefined(u[0].report)) {
          alert('There are no submissions.')
          return;
        }

        var status = u[0].report[this.props.report].status;

        switch (status) {
        case 'report':
        case 'OK':
        case 'check:NG':
          api.get({
            api: 'test_result',
            data: data
          }).done(function(result) {
            var score_hash = _.cloneDeep(this.state.score_hash);
            result.detail.forEach(function(d) {
              score_hash[d.ex] = (d.result === 'OK');
            }.bind(this));
            this.setState({
              score_hash: score_hash
            });
          }.bind(this));
          break;
        default:
          alert('There are no results. Status: \'' + status + '\'');
        }
      }.bind(this));
    },

    submitScore: function() {
      var content = JSON.stringify(this.state.score_hash).replace(/:/g, '=> ');
      var data = {
        action: 'post',
        scoree: this.props.token,
        report: this.props.report,
        content: content
      };

      api.post({
        api: 'score',
        data: data
      }).done(function() {
        this.props.updateScore(this.props.login, this.props.report, content);
        this.setTemplateText();
        this.props.reload();
      }.bind(this));
    },

    toggleCheck: function(key) {
      return function(event) {
        this.state.score_hash[key] = event.target.checked;
        this.setState({
          score_hash: this.state.score_hash
        });
      }.bind(this);
    },

    render: function() {
      checkboxes = Object.keys(this.state.score_hash).map(function(key) {
        return (
          <div>
            <input type="checkbox" checked={this.state.score_hash[key]} onChange={this.toggleCheck(key)} />
            {key}
          </div>
        );
      }.bind(this));

      return (
        <span>
          {checkboxes}
          <button onClick={this.synchronizeWithTestResult}>自動テストと同期</button>
          <button onClick={this.submitScore}>採点</button>
        </span>
      );
    }
});

var ScoreView = React.createClass({
    refleshScores: function() {
        if (!ScoreView.visible(this.props)) return;

        api.get({
            api: 'score',
            data: {
                scoree: this.props.token,
                report: this.props.report,
                action: 'get'
            }
        }).done(function(result) {
            this.setState({ scores: result });
        }.bind(this));
    },

    getInitialState: function() {
        return {
            scores: []
        }
    },

    componentDidMount: function() {
        this.refleshScores();
    },

    render: function() {
        if (!ScoreView.visible(this.props)) return <div />;

        var scores = this.state.scores;
        var last_id;
        if (scores.length > 0) {
          last_id = scores[scores.length-1].id;
        }
        scores = scores.map(function(score) {
            console.log('SCORE VIEW');
            console.log(score);
            var div_meta = (
              <div className="meta">
                <p className="author">{score.scorer_name}</p>
                <p className="date">{score.timestamp}</p>
              </div>
            );
            var div_form = (
              <div className="form">
                <Highlight className="message">
                {score.content}
                </Highlight>
              </div>
            );

            if (score.id !== last_id) {
              return (
                <li className="private">{div_meta}{div_form}</li>
              );
            } else {
              return (
                <li>{div_meta}{div_form}</li>
              );
            }
        }.bind(this));
        return (
            <div>
                <div className="status_view">
                  <ul className="comments">
                    {scores}
                    <li>
                      <ScoreForm login={this.props.login}
                                 token={this.props.token}
                                 report={this.props.report}
                                 reload={this.refleshScores}
                                 updateScore={this.props.updateScore} />
                    </li>
                  </ul>
                </div>
            </div>
        );
    },

    statics: {
        visible: function(params) {
            return params.admin;
        }
    }
});

module.exports = ScoreView;
