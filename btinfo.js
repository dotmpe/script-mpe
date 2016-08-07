var _ = require('lodash');
var fs = require('fs');
var parseTorrent = require('parse-torrent')

fn = process.argv[2]
console.log('fn="'+ fn +'"')

var btmetainfo = parseTorrent(fs.readFileSync(fn))
//console.log(_.keys(btmetainfo))

console.log('name="'+ btmetainfo['name']+'"')
if ('files' in btmetainfo) {
    //console.log('files='+( btmetainfo['files'].join(',')))
}
//console.log('pieces='+ btmetainfo['pieces'])
console.log('pieceLength='+ btmetainfo['pieceLength'])
//console.log('urlList='+ btmetainfo['urlList'].join(','))
console.log('length='+ btmetainfo['length'])
console.log('lastPieceLength='+ btmetainfo['lastPieceLength'])
console.log('infoHash='+ btmetainfo['infoHash'])
