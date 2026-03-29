#ifndef US_ENV_SH_H
#define US_ENV_SH_H
# FIXME: us-env -r us-env
[[ ${US_ENV_PARTS:+set} ]] &&
[[ ${US_ENV_INIT:+set} ]] &&
eval "$US_ENV_INIT" || {
  >&2 echo "Expected User-Script env"
  exit 121
}
#endif
