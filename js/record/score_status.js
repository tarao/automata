var _ = require('lodash');
var React = require('react');

module.exports = React.createClass({
    render: function() {
        if (this.props.score=='')
          return <div>未採点</div>;

        var answers = this.props.score==''?{}:JSON.parse(this.props.score.replace(/=>/g, ': '));
        var e = this.props.exercises;

        var required_e = _.filter(e, function (a) { var info = a[1]; return info.required; });
        var cnt_required = _.filter(required_e, function(a) { var name = a[0]; return answers[name]; }).length;
        var required = <div>必修: {cnt_required}/{required_e.length}</div>
        
        var max_level = _.chain(e)
                         .map(function (a) {
                            var info = a[1];
                            return _.isUndefined(info.level)?0:info.level;
                         }).max().value();
        var iii = _.map(e, function (a) {
                      var info = a[1];
                      return _.isUndefined(info.level)?0:info.level;
                   });
        var levels = (_.isUndefined(max_level) || max_level == 0)?[ <div /> ]:new Array(max_level);
        for (i = 1; i <= max_level; i++) {
          level_i_e = _.filter(e, function(a) { var info = a[1]; return info.level ==  i; });
          cnt_level_i = _.filter(level_i_e, function(a) { var name = a[0]; return answers[name]; }).length;
          if (level_i_e.length == 0)
            length[i-1] = <div />;
          else
            levels[i-1] = <div>星 {i}: {cnt_level_i}/{level_i_e.length}</div>;
        }

        var other_e = _.filter(e, function(a) {
          var info = a[1];
          return !info.required && _.isUndefined(info.level);
        });
        var cnt_other = _.filter(other_e, function(a) { var name = a[0]; return answers[name]; }).length;
        var other = other_e.length==0?<div />:<div>その他 {cnt_other}/{other_e.length}</div>;

        return (
            <div>{required}{levels}{other}</div>
        );
    }
});
