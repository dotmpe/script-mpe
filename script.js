#!/usr/bin/env node
var levelup = require('levelup'),
  neodoc = require('neodoc');

var expand_shell = function(str) {
  return str.replace(/\$([A-Za-z0-9_]+)/g, function(_, n) {
      return process.env[n];
  });
}

var defaultDict = function(map, def) {
  return function(key) {
    if (key in map) v = map[key];
    else v = def
    //if (typeof v == "function") return v();
    return v;
  };
}

var getdefault = function(map, key, def) {
  if (key in map) v = map[key];
  else v = def
  return v;
}


const opts = neodoc.run(`
    usage: script.js [--version] [--help]
                     <command> [<args>...]
`, { optionsFirst: true, smartOptions: true });


if (opts['<command>'] === 'leveldb') {

  const ldopts = neodoc.run(`
      usage: script.js leveldb init [<db>]
             script.js leveldb stream [<db>]
             script.js leveldb x [<db>]
  `, { argv: ['leveldb'].concat(opts['<args>']), smartOptions: true })

  if (opts['<args>'][0] === 'init') {


  } else if (opts['<args>'][0] === 'stream') {

    var dbpath = expand_shell(getdefault(ldopts, '<db>', './mydb'));
    var db;
    try {
      db = levelup(dbpath)
    } catch (e) {
      console.error(e);
      console.error("Failed opening DB at "+dbpath);
      process.exit(1);
    }

		db.createReadStream()
			.on('data', function (data) {
				console.log(data.key, '=', data.value)
			})
			.on('error', function (err) {
				console.log('Oh my!', err)
			})
			.on('close', function () {
				console.log('Stream closed')
			})
			.on('end', function () {
				console.log('Stream ended')
			});

  } else if (opts['<args>'][0] === 'x') {

    var dbpath = expand_shell(getdefault(ldopts, '<db>', './mydb'));
    console.log( 'creating DB at', dbpath );

    // 1) Create our database, supply location and options.
    //    This will create or open the underlying LevelDB store.
    var db = levelup(dbpath)

    // 2) put a key & value
    db.put('name', 'LevelUP', function (err) {
      if (err) return console.log('Ooops!', err) // some kind of I/O error

      // 3) fetch by key
      db.get('name', function (err, value) {
        if (err) return console.log('Ooops!', err) // likely the key was not found

        // ta da!
        console.log('name=' + value)
      })
    });


  } else {
    console.log("Unknown command args", opts['<args>']);
    process.exit(1);
  }

} else {
  console.log("Unknown command", opts['<command>']);
  process.exit(1);
}
