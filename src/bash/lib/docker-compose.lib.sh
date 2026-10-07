#!/bin/sh

# Helper for in-container docker-compose to pass env (via COMPOSE_OPTIONS)
docker_compose_env()
{
  for env in "$@"
  do COMPOSE_OPTIONS="$COMPOSE_OPTIONS -e $env=$(eval echo \"\$$env\")"
  done
  unset env
  export COMPOSE_OPTIONS
}
