var _ = require('lodash');
var React = require('react');
var Router = require('react-router');
var DefaultRoute = Router.DefaultRoute;
var Link = Router.Link;
var Route = Router.Route;
var RouteHandler = Router.RouteHandler;
var $ = require('jquery');
require('jquery.cookie');
var api = require('../api');
var ui = require('../ui2');
var Loading = require('../loading');

var DetailList = require('./detail_list.js');
var SummaryList = require('./summary_list.js');
var UserRoute = require('./user.js');
var AutoReload = require('./auto_reload.js');

var Record = React.createClass({
    mixins: [
        Router.Navigation,
        Router.State,
        Loading.Mixin
    ],

    toggleFilter: function() {
        $.cookie('default-filtered', !this.state.filtered);
        this.setState({
            filtered: !this.state.filtered
        });
    },

    updateStatus: function(token, report, status) {
        this.setState({
            users: this.state.users.map(function(user) {
                if (user.token === token) {
                    user.report[report].status = status;
                }
                return user;
            })
        });
    },

    changeDelayStatus: function(token, report, delay) {
        var users = this.state.users;
        users.forEach(function(user) {
            if (user.token === token) {
                user.report[report].delay = delay;
            }
        });
        this.setState({ users: users });
    },

    updateNews: function(token, report, news) {
        ['comments', report, token].reduce(function(r, k) {
            if (!_.has(r, k)) r[k] = {};
            return r[k];
        }, this.state);
        this.state.comments[report][token] = news;
        this.setState({
            comments: this.state.comments
        });
    },

    updateScores: function(scheme) {
        var params = scheme.map(function(report) {
            return {
                api: 'scheme',
                data: { id: report.id, type: report.type, exercise: true }
            };
        });

        api.get.apply(null, params).done(function() {
            var reports = _.toArray(arguments).map(function(r) { return r[0]; });

            if (this.isMounted()) {
              this.setState({
                reports: reports
              });
            }
        }.bind(this));

        api.get({
            api: 'score',
            data: { action: 'tabulate' }
        }).done(function (scores) {
            if (this.isMounted()) {
              this.setState({
                scores: scores
              });
            }
        }.bind(this));
    },

    updateScore: function(login, report, score) {
      if(_.isUndefined(this.state.scores)) {
        return;
      }
      
      var scores = _.cloneDeep(this.state.scores);
      scores[login][report] = score;
      this.setState({
        scores: scores
      });
    },

    queryComments: function(tokens) {
        api.get({ api: 'comment', data: { action: 'list_news', user: tokens } })
           .done(function(comments) {
               if (this.isMounted()) this.setState({ comments: comments });
           }.bind(this));
    },

    setComments: function(comments) {
        if (this.isMounted()) {
            this.setState({
                comments: comments
            })
        }
    },

    setUsers: function(users) {
        if (this.isMounted()) {
            this.setState({
                users: users
            })
        }
    },

    componentDidMount: function() {
        api.get(
            {
                api: 'master',
                data: {
                    user: true,
                    admin: true,
                    token: true,
                    delay_options: true,
                    reload: true,
                    interact: true
                }
            },
            {
                api: 'scheme',
                data: { record: true }
            },
            {
                api: 'user',
                data: {
                    type: 'status',
                    status: 'record',
                    log: true,
                    assigned: true
                }
            }
        ).done(function(master, scheme, users) {
            var filtered = $.cookie('default-filtered');
            if (typeof filtered === 'undefined' || filtered === 'true') {
                filtered = true;
            } else {
                filtered = false;
            }
            $.cookie('default-filtered', filtered);
            if (this.isMounted()) {
                this.setState({
                    user: master.user,
                    token: master.token,
                    admin: master.admin,
                    reload: master.reload,
                    interact: master.interact,
                    delayOptions: master.delay_options,
                    scheme: scheme,
                    users: users,
                    comments: {},
                    filtered: filtered
                });
            }
            if (master.admin) {
              this.updateScores(scheme);
            }
            this.queryComments(users.map(_.partial(_.result, _, 'token')));
            if (!master.admin && this.getPath() === '/') {
                var report = $.cookie('default-report');
                if (!report) report = scheme[0].id;
                this.replaceWith('user', {
                    token: master.token,
                    report: report
                });
            }
        }.bind(this));
    },

    nowLoading: function() { return !this.state; },

    afterLoading: function() {
        var filter;
        if (this.state.admin) {
            if (this.state.filtered) {
                filter = (
                        <li>
                        <label>
                        <input type="checkbox" onChange={this.toggleFilter} checked/>
                        担当学生のみ
                        </label>
                        </li>
                );
            } else {
                filter = (
                        <li>
                        <label>
                        <input type="checkbox" onChange={this.toggleFilter}/>
                        担当学生のみ
                        </label>
                        </li>
                );
            }
        }

        var users = _.filter(this.state.users, function(user) {
            return !this.state.admin
                || !this.state.filtered
                || user.token === this.state.token
                || user.assigned === this.state.user;
        }.bind(this));

        Object.keys(this.state.comments).map(function(report_id) {
            var comments = this.state.comments[report_id];
            Object.keys(comments).map(function(key) {
                var user = _.find(users, function(user) {
                    return user.token === key;
                });
                if (typeof user === 'undefined') return;
                ['report', report_id, 'comment'].reduce(function(r, k) {
                    if (typeof r[k] === 'undefined') r[k] = {};
                    return r[k]
                }, user);
                user.report[report_id].comment = comments[key];
            });
        }, this);

        var scores = this.state.users.reduce(function(uhash, u) {
          uhash[u.login] = this.state.scheme.reduce(function(shash, s) {
            shash[s.id] = _.get(this.state.scores, [u.login, s.id], '');
            return shash;
          }.bind(this), {});
          return uhash;
        }.bind(this), {});

        var reports = this.state.scheme.reduce(function(rhash, s) {
          var d = _.isUndefined(this.state.reports)
                ? {}
                : this.state.reports.find(function(r) {
                    return r.id === s.id;
                  });
          var e = _.get(d, 'exercise', {});
          d['exercise'] = e;
          rhash[s.id] = d;
          return rhash;
        }.bind(this), {})

        return (
            <div>
                <div id="view_switch">
                    表示:<ul>
                        <li>
                            <AutoReload interval={this.state.reload}
                                        comments={this.state.comments}
                                        users={this.state.users}
                                        setComments={this.setComments}
                                        setUsers={this.setUsers}/>
                        </li>
                        {filter}
                        <li><Link to="detail" id="sw_view_report">課題ごと</Link></li>
                        <li><Link to="summary" id="sw_view_summary">一覧</Link></li>
                    </ul>
                </div>

                <RouteHandler admin={this.state.admin}
                              interact={this.state.interact}
                              scheme={this.state.scheme}
                              users={users}
                              scores={scores}
                              reports={reports}
                              updateStatus={this.updateStatus}
                              changeDelayStatus={this.changeDelayStatus}
                              delayOptions={this.state.delayOptions}
                              loginUser={this.state.user}
                              updateNews={this.updateNews}
                              updateScore={this.updateScore}
                              comments={this.state.comments}/>
            </div>
        );
    },

    render: Loading.Mixin.renderLoading
});

var routes = (
        <Route name="record" path="/" handler={Record}>
        <Route name="detail" path="detail" handler={DetailList}/>
        <Route name="summary" path="summary" handler={SummaryList}/>
        {UserRoute}
        <DefaultRoute handler={SummaryList}/>
        </Route>
);

Router.run(routes, function(Handler) {
    React.render(<Handler/>, document.getElementById('record'));
});

$(document).ready(function() {
    api.get({ api: 'template', data: { type: 'record', links: true } }).
        done(function(template) {
            ui.setTitle(template);
            ui.addLinks(template.links);
        });
});
