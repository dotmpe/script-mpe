#!/usr/bin/env bats

load init
base=env-deps.lib
init

@test "${lib}/${base} - lib loads" {

  lib_load env-deps
	func_exists boxenv_dep_puml
	func_exists boxenv_git
	func_exists boxenv_Git_ProjectId
	func_exists build_ssh_tunnel_setup
	func_exists build_ssh_tunnel_teardown
}

