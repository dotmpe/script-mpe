

alias user-bg='user-bg.sh run-cmd'
alias user-bg-eval='user-bg.sh run-eval'

# Inherit v from current shell or set maximum verbosity
alias user-bg-v='user-bg-eval eval v=${v:-${verbosity:-7}}'

alias user-bg-debug='user-bg-eval eval DEBUG=true UC_DEBUG=true US_DEBUG=true'

alias user-bg-vv='user-bg eval echo \
v=\${v:-\${verbosity:-\(unset\)}} \
uc_log=\${uc_log:-\(unset\)} \
LOG=\${LOG:-\(unset\)} \
INIT_LOG=\${INIT_LOG:-\(unset\)} \
UC_LOG_LEVEL=\${UC_LOG_LEVEL:-\(unset\)} \
DEBUG=\${DEBUG:-\(unset\)} \
UC_DEBUG=\${UC_DEBUG:-\(unset\)} \
US_DEBUG=\${US_DEBUG:-\(unset\)} '


# Load uc-profile helpers
alias user-bg-init='
  user-bg-eval lib_require lib-uc &&
  user-bg-eval lib_init &&
  user-bg-eval lib_require \
    shell-uc str-uc argv-uc stdlog-uc ansi-uc syslog-uc \
    uc-profile &&
  user-bg-eval lib_init &&
  user-bg-eval . ${U_C:?}/tools/sh/log.sh &&
  user-bg-eval uc_log_init '

# Execute uc-profile
alias user-bg-start='
  user-bg-eval uc_profile_boot "" preload &&
  user-bg-eval uc_profile_init user-bg &&
  user-bg-eval uc_profile_boot "" profile &&
  user-bg-eval uc_profile_boot "" rc
  user-bg-eval uc_source ~/.alias'

# Restart user-bg session with full user profile
alias user-bg-restart='
  user-bg.sh run reset &&
  user-bg-v &&
  { ! "${DEBUG:-false}" || user-bg-debug; } &&
  user-bg-init &&
  user-bg-start '


#
