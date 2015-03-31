var _ = require('lodash');
var React = require('react');
var Router = require('react-router');
var Link = Router.Link;
var $ = require('jquery');
var api = require('../api');
var CopyToClipboard = require('./copy_to_clipboard.js');

var FileEntry = (function() {
    var humanReadableSize = function(size) {
        var prefix = [ '', 'K', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' ];
        var i;
        for (i=0; size >= 1024 && i < prefix.length-1; i++) {
            size /= 1024;
        }
        if (i > 0) size = size.toFixed(1);
        return size + prefix[i];
    };

    return React.createClass({
        render: function() {
            var p = this.props;
            var entry = p.entry;
            var uri = FileView.rawPath(p.token, p.report, p.path+'/'+p.entry.name);
            var suffix = entry.type === 'dir' ? '/' : '';

            var params = {
                token: p.token,
                report: p.report,
                splat: p.path + '/' + p.entry.name
            };
            var link = (entry.type === 'bin')
                ? (<a href={uri}>{entry.name + suffix}</a>)
                : (<Link to="file-pathParam" params={params}>{entry.name + suffix}</Link>);
            return (
                <tr>
                    <td className="file">
                        <img className="icon"
                             src={"./" + entry.type + ".png"} />
                        {link}
                    </td>
                    <td className="size">{humanReadableSize(entry.size)}</td>
                    <td className="time">{entry.time}</td>
                </tr>
            );
        }
    });
})();

var Breadcrum = (function() {
    var descend = function(path) {
        return path.split('/').reduce(function(r, p) {
            r[1].push(p);
            r[0].push({ name: p, path: r[1].join('/') });
            return r;
        }, [ [], [] ])[0];
    };

    return React.createClass({
        rawPath: function(path) {
            return FileView.rawPath(this.props.token, this.props.report, path);
        },

        render: function() {
            var p = this.props;
            var list = descend(p.path).map(function(loc) {
                if (loc.name === '.') loc.name = p.report;
                return loc;
            });

            var copyButton = last.type === 'dir' ? null : (
                <li className="toolbutton">
                    <CopyToClipboard text={this.props.rawContent}
                                     selector={'.file .content'}/>
                </li>
            );

            var self = this;
            var last = list.pop();
            var items = list.map(function(loc) {
                var params = {
                    token: p.token,
                    report: p.report,
                    splat: loc.path
                };
                return <li><Link to={'file-pathParam'} params={params}>{loc.name}</Link></li>;
            });
            items.push(<li>{last.name}</li>);

            var toolButton = p.type === 'dir' ? null :
                <li className="toolbutton">
                    <a href={this.rawPath(last.path)}>⏎ 直接開く</a>
                    <ReactZeroClipboard text={this.props.rawContent}>
                        <button>Copy</button>
                    </ReactZeroClipboard>
                </li>;

            return (<ul id={"summary-" + p.report + "_status_toolbar"}
                         className="status_toolbar">
                        <li>場所:
                            <ul id={p.report + '-breadcrum'}
                                className='breadcrums'>{items}</ul>
                        </li>
                        {toolButton}
                        {copyButton}
                    </ul>);
        }
    });
})();

var FileBrowser = React.createClass({
    render: function() {
        var p = this.props;
        var rows = p.entries.map(function(entry) {
            return (<FileEntry entry={entry}
                               path={p.path}
                               token={p.token}
                               report={p.report}
                               parent={self}
                    />);
        });

        return (
            <table className="file_browser">
                <tr>
                    <th className="file">ファイル</th>
                    <th className="size">サイズ</th>
                    <th className="time">更新日時</th>
                </tr>
                {rows}
            </table>
        );
    }
});

var FileViewer = (function() {
    return React.createClass({
        render: function() {
            var content = this.props.content;

            // line number
            var ln = '';
            var i = 1, arr;
            var re = new RegExp("\n", 'g');
            while ((arr = re.exec(content)) !== null) {
                ln += i++ + "\n";
            }

            return <table className="file_browser file"><tr>
                <td className="linenumber"><pre>{ln}</pre></td>
                <td className="content"><pre dangerouslySetInnerHTML={
                    {__html: content }
                }/></td>
            </tr></table>;
        }
    });
})();

var FileView = (function() {

    var d = document;

    var applyStyle = function(rules) {
        if (d.styleSheets[0].addRule) { // IE
            rules.forEach(function(s) {
                d.styleSheets[0].addRule(s.selector, s.style);
            });
            return true;
        } else {
            var style = $('<style type="text/css" />');
            style.append(rules.map(function(s) {
                return s.selector+'{'+s.style+'}';
            }).join("\n"));

            var head = d.getElementsByTagName('head')[0];
            if (head) {
                head.appendChild(style[0]);
                return true;
            }
        }
    };

    var applyStyleFromSource = function(source) {
        source = source.replace(/[\r\n]/g, '');
        var regex = '<style[^>]*>(?:<!--)?(.*?)(?:-->)?</style>';
        if (new RegExp(regex).test(source)) {
            var rawcss = RegExp.$1;
            var arr;
            var re = new RegExp('\\s*([^\{]+?)\\s*{([^\}]*)}','g');
            var rules = [];
            while ((arr = re.exec(rawcss)) !== null) {
                if (arr[1].charAt(0) == '.') {
                    rules.push({selector: arr[1], style: arr[2]});
                }
            }
            return applyStyle(rules);
        }
    };

    return React.createClass({
        mixins: [Router.State],

        open: function(path) {
            var data = _.chain({
                user: this.props.token,
                report: this.props.report,
                path: path
            });
            api.get(
                { api: 'browse', data: data.clone().assign({ type: 'highlight' }).value() },
                { api: 'browse', data: data.clone().assign({ type: 'raw' }).value() }
            ).done(function() {
                var args = _.toArray(arguments);
                var newState = {
                    path: path,
                    rawContent: args[1],
                    mode: 'show'
                }
                switch (args[4].getResponseHeader('content-type')) {
                    case 'application/json':
                        _.assign(newState, {
                            type: 'dir',
                            entries: args[0]
                        });
                        break;
                    case 'text/html':
                        var div = $('<div />')[0];
                        var content = args[0].replace('<pre>\n', '<pre>');
                        div.innerHTML = content;
                        var pre = div.getElementsByTagName('pre')[0];
                        if (content.charAt(content.length-1) != "\n") {
                            content += "\n";
                        }
                        applyStyleFromSource(args[0]);
                        _.assign(newState, {
                            type: 'highlight',
                            content: pre.innerHTML+''
                        });
                        break;
                    default:
                        _.assign(newState, {
                            mode: 'error'
                        });
                        break;
                }
                this.setState(newState);
            }.bind(this)).fail(function() {
                this.setState({
                    mode: 'error'
                });
            }.bind(this));

            this.setState({
                mode: 'loading'
            })
        },

        getInitialState: function() {
            return {
                path: '.',
                type: 'dir',
                entries: [],
                mode: 'loading'
            };
        },

        componentDidMount: function() {
            this.open(_.result(this.getParams(), 'splat', '.'));
        },

        componentWillReceiveProps: function() {
            this.open(_.result(this.getParams(), 'splat', '.'));
        },

        render: function() {
            var s = this.state;
            var p = this.props;
            var open = this.open;

            var toolBar = function() {
                return <Breadcrum token={p.token}
                                  report={p.report}
                                  path={s.path}
                                  type={s.type}
                                  rawContent={s.rawContent}/>;
            }.bind(this);

            var render;
            switch (s.mode) {
                case 'loading':
                    render = <i className="fa fa-spinner fa-pulse"/>;
                    break;
                case 'show':
                    if (s.type === 'dir') {
                        render = [
                            (
                                <a className="download"
                                   href={api.root+'/download/'+p.token+'/'+p.report+'.zip'}>
                                    ☟ダウンロード
                                </a>
                            ),
                            (
                                <FileBrowser token={p.token}
                                             report={p.report}
                                             path={s.path}
                                             entries={s.entries}/>
                            )
                        ];
                    } else {
                        render = <FileViewer  content={s.content}/>;
                    }
                    break;
                default:
                    render = 'なし';
            }

            return (<div id={"summary-" + p.report + "_status_window"}
                         style={ {display: "block"} }>
                          <div className="status_header">{toolBar()}</div>
                          <div id={"summary-" + p.report + "_status_view"}
                               className="status_view">
                              {render}
                          </div>
                    </div>);
        }
    });
})();

FileView.encodePath = function(path) {
    return [
        [ '&', '%26' ],
        [ '\\?', '%3F' ]
    ].reduce(function(r, x) {
        return r.replace(new RegExp(x[0], 'g'), x[1]);
    }, encodeURI(path));
};

FileView.rawPath = function(user, report, path) {
    var epath = FileView.encodePath(path);
    pathname = '/browse/'+user+'/'+report+'/'+epath;
    var param = path != epath ? ('?path=' + epath) : '';
    return api.root + pathname + param;
};

module.exports = FileView;
