var _ = require('lodash');
var React = require('react');

module.exports = React.createClass({
    render: function() {
        if (this.props.score === '') {
          return <div>未採点</div>;
        }

        var submissions = JSON.parse(this.props.score.replace(/=>/g, ': '));
        var e = this.props.exercises;

        var required_e = e.filter(function (a) {
          var info = a[1];
          return info.required;
        });
        var accept_cnt_required = required_e.filter(function(a) {
          var name = a[0];
          return submissions[name];
        }).length;
        var required = <div>必修: {accept_cnt_required}/{required_e.length}</div>

        var star_e = e.filter(function (a) {
          var info = a[1];

          // Discard a exercise with "required" in order not to double count
          return !info.required;
        });
        var max_level = _.chain(star_e)
                         .map(function (a) {
                            var info = a[1];
                            return _.isUndefined(info.level) ? 0 : info.level;
                         }).max().value();
        var levels = (_.isUndefined(max_level) || max_level === 0)
                   ? [ <div /> ]
                   : new Array(max_level);
        for (var i = 1; i <= max_level; i++) {
          var level_i_e = star_e.filter(function(a) {
            var info = a[1];
            return info.level === i;
          });

          if (level_i_e.length === 0) {
            levels[i-1] = <div />;
          } else {
            var accept_cnt_level_i = level_i_e.filter(function(a) {
              var name = a[0];
              return submissions[name];
            }).length;

            levels[i-1] = <div>星 {i}: {accept_cnt_level_i}/{level_i_e.length}</div>;
          }
        }

        var other_e = e.filter(function(a) {
          var info = a[1];
          return !info.required && _.isUndefined(info.level);
        });
        var accept_cnt_other = other_e.filter(function(a) {
          var name = a[0];
          return submissions[name];
        }).length;
        var other = other_e.length === 0
                  ? <div />
                  : <div>その他 {accept_cnt_other}/{other_e.length}</div>;

        return (
            <div>{required}{levels}{other}</div>
        );
    }
});
