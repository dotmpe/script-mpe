/**
 * Helper for Travis CI
 */
var fs = require('fs');

if (!process.env.CI_DB_INFO.trim() && process.env.CI_DB_HOST.trim()) {
    console.error("DB host and access info requried");
    process.exit(2);
}
var url = "https://"+process.env.CI_DB_INFO+"@"+process.env.CI_DB_HOST;
var dbname = process.env.CI_DB_NAME;
var key = process.env.TRAVIS_REPO_SLUG;

console.log("update-couchdb-testlog: DB '"+dbname+"', key: "+key);

var server = require('nano')(url);
var db = server.db.use(dbname);
var buildkey = key+':'+process.env.TRAVIS_JOB_NUMBER;

var before_install_ts = parseInt(process.env.before_install_ts);
var install_ts = parseInt(process.env.install_ts);
var before_script_ts = parseInt(process.env.before_script_ts);
var script_ts = parseInt(process.env.script_ts);
var after_script_ts = parseInt(process.env.after_script_ts);
var before_cache_ts = parseInt(process.env.before_cache_ts);

var results = JSON.parse(fs.readFileSync(process.env.CI_BUILD_RESULTS));
var build = {
  "env": {},
  "cause": process.env.BUILD_CAUSE,
  "times": {
    "before-install": before_install_ts,
    "install": install_ts,
    "before-script": before_script_ts,
    "script": script_ts,
    "before-cache": before_cache_ts,
    "after-script": after_script_ts,
    "init-duration": script_ts - before_install_ts,
    "build-duration": before_cache_ts - script_ts,
    "pre-publish-duration": after_script_ts - before_install_ts
  },
  "stats": {
    "total": results.stats.asserts,
    "passed": results.stats.passes,
    "failed": results.stats.failures
  },
  "tests": results.asserts
};

var paramsFile = process.env.CI_BUILD_ENV;
var env = {};
if (fs.existsSync(paramsFile)) {
  build.env = JSON.parse(fs.readFileSync(paramsFile));
}
if (!build.env) {
  for (k in process.env) {
    for (pref in ['PROJECT','BUILD','JOB','JENKINS','TRAVIS']) {
      if (k.substr(0, pref.length).upper() == pref) {
        build.env[k] = process.env[k];
      }
    }
  }
}

db.update = function(obj, key, callback) {
  var db = this;
  db.get(key, function (error, existing) {
    if (!error) {
      obj._rev = existing._rev;
      console.log(key, "updating:", obj._rev);
    }
    db.insert(obj, key, callback);
  });
}

// Store or update build number
db.update(build, buildkey, function(err) {
  if (err) {
    console.error(err.statusCode);
    process.exit(1);
  }
});

// Set latest build info
db.get(key, function( err, buildlog, headers ) {

  if (err) {
    console.error(err.statusCode);
    process.exit(1);
  }

  if (!buildlog) {
    buildlog = {"builds": {}};
  }
  buildlog.builds[process.env.TRAVIS_JOB_NUMBER] = {
    "stats": build.stats,
    "cause": process.env.BUILD_CAUSE,
    "times": {
      "init-duration": build.times['init-duration'],
      "build-duration": build.times['build-duration'],
      "pre-publish-duration": build.times['pre-publish-duration']
    },
    "scm": {
      "commits": process.env.BUILD_COMMIT_RANGE,
      "branch": process.env.BUILD_BRANCH,
    }
  };

  db.insert( buildlog, key, function(error) {

     if (err) {
       console.error(err.statusCode);
       process.exit(1);
     }
     console.log("OK, updated", buildkey);
  });
});

// Id: script-mpe/0.0.4-dev tools/update-couchdb-testlog.js
