var stdin = process.stdin
var stdout = process.stdout
var buf = ""

stdin.setEncoding('utf8')

var vm = require('vm');
var contexts = {};

/*
 * Versions of node before 0.12 (notably 0.10) didn't properly propagate
 * syntax errors.
 * This also regressed in the node 4.0 releases.
 *
 * To get around this, if it looks like we are missing the location of the
 * error, we guess it is (execjs):1
 *
 * This is obviously not ideal, but only affects syntax errors, and only on
 * these versions.
 */
function massageStackTrace(stack) {
  if (stack && stack.indexOf("SyntaxError") == 0) {
    return "(execjs):1\n" + stack;
  } else {
    return stack;
  }
}

function getContext(uuid) {
  return contexts[uuid] || (contexts[uuid] = vm.createContext())
}

var commands = {
  deleteContext: function(uuid) {
    delete contexts[uuid];
    return 1;
  },
  exit: function(code) {
    process.exit(code)
  },
  exec: function execJS(input) {
    var context = getContext(input.context);
    var source = input.source;
    try {
      var program = function(){
        return vm.runInContext(source, context, "(execjs)");
      }
      result = program();
      if (typeof result == 'undefined' && result !== null) {
        return ['ok'];
      } else {
        try {
          return ['ok', result];
        } catch (err) {
          return ['err', '' + err, err.stack];
        }
      }
    } catch (err) {
      return ['err', '' + err, massageStackTrace(err.stack)];
    }
  }
}

var http = require('http')
var server = http.createServer(function(req, res) {
  var contents = '';

  req.on('data', function (dataIn) {
    contents += dataIn;
  });

  req.on('end', function () {
    var input = JSON.parse(contents)
    var result = commands[input.cmd].apply(null, input.args)
    var outputJSON = JSON.stringify(result)

    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json');
    res.end(outputJSON);
  });
});

var port = process.env.PORT || 3001;
server.listen(port);
