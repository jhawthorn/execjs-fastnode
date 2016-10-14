(function(){
  var stdin = process.stdin
  var stdout = process.stdout
  var buf = ""

  stdin.setEncoding('utf8')

  var vm = require('vm');
  var contexts = {};

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
        return ['err', '' + err, err.stack];
      }
    }
  }

  function processLine(line){
    var input = JSON.parse(line)
    var result = commands[input.cmd].apply(null, input.args)

    var outputJSON = JSON.stringify(result)
    stdout.write(outputJSON)
    stdout.write('\n')
  }

  function processBuffer(){
    if(buf.indexOf('\n') >= 0){
      var lines = buf.split('\n')
      for(var i = 0; i < lines.length - 1; i++) {
        processLine(lines[i]);
      }
      buf = lines[lines.length - 1]
    }
  }

  process.stdin.on('readable', function(){
    var chunk = process.stdin.read();
    if (chunk !== null) {
      buf += chunk
      processBuffer()
    }
  });
})();
