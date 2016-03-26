
// Track each component individually
def success = []
def unstable = []
def failed = []


stage 'Configuration'

String jjb_server = 'localhost:8080'

node('master') {
  stage 'JJB server selection'
  if (jjb_server) {
    set_job_server '${jjb_server}'
  } else {
    echo 'Using any JJB server'
  }
  stage 'JJB build configs'
  guard {
    configure_job '{name}-gh-travis', [ name:'script.mpe' ]
    configure_job '{name}-local-gh-travis', [ name:'script.mpe' ]
    configure_job '{name}-local-gh', [ name:'script.mpe' ]
    configure_job '{name}-local-gh-bats', [ name:'script.mpe' ]
  } rescue {
    // Set failed: abort tests and other builds.
    failed.push 'JJB build configs'
  }
}

if (failed.empty) {

  checkpoint 'Tests'
  node('slave') {
    build 'script.mpe-gh-travis'
    build 'script.mpe-local-gh-travis'
    build 'script.mpe-local-gh'
    build 'script.mpe-local-gh-bats'
  }

  build_component 'Matchbox', 'matchbox'

}

finalize success, unstable, failed


 /* Routines */

// Require the given hostspec in /etc/jenkins_jobs/jenkins_jobs.ini, or raise
// exception.
def set_job_server(hostspec) {
  
}
// Run jenkins-jobs update
def configure_job(tpl_id, name) {
  // XXX: this does require a customized jjb
  //sh 'jenkins-jobs update ${name}'
}
def build_component(clabel, cname) {
  checkpoint '${clabel} build'
  node('slave') {
    stage '${clabel} test'
    guard {
      // Test BATS ${cname} spec only
      build 'script.mpe-local-gh-bats', SPEC:'${cname}'
      // Mark ${cname} as unstable
      //unstable.push '${cname}' XXX: get testlog from the build
    } rescue {
      // Mark ${cname} tests as failed
      failed.push '${cname}'
    }
    // Check for version, changelog 
    finalize_component '${cname}', '${cname}' in failed, '${cname}' in unstable
  }
}
// Post-run checks, possibly tag/commit/trigger..
def finalize_component(cname, err, nok) {
}
def finalize(ok, nok, err) {
}

