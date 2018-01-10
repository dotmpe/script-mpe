#!/bin/sh

# Detect dependencies.

# NOTE: These are accumulated into a file so that both the env/user script
# and Bats can include them. Bats tests will not inherit the functions from
# the parent process otherwise.


boxenv_dep_puml()
{
	java -jar brixadmin/lib/plantuml.jar -V >/dev/null 2>&1
	return $?
}


# XXX: see install-deps.
#boxenv_bin_dep=
#boxenv_bin()
#{
#	export htd=$scriptpath/htd.sh
#}


boxenv_git()
{
  test -x "$(which git)"
  export Git_Version="$(git --version)"
}
# TODO: provides
boxenv_git_provides=Git_Version


boxenv_Git_ProjectId_deps=git
boxenv_Git_ProjectId()
{
	test -n "$1" || set -- origin
	test -z "$2" || error surplus-arguments 1
	basename $(git config --get remote.$1.url) .git
}


build_ssh_tunnel_setup()
{
	# XXX: Build_SSH_Tunnnel_Remote=project@bastion.cloud.net

	note "SSH-Tunnel: ${Build_SSH_Tunnel_Local_Port}:${Build_SSH_Host}:${Build_SSH_Tunnel_Remote_Port} ${Build_SSH_Tunnnel_Remote}"
	ssh -N \
		-L ${Build_SSH_Tunnel_Local_Port}:${Build_SSH_Host}:${Build_SSH_Tunnel_Remote_Port} ${Build_SSH_Tunnnel_Remote} &
	export tunnel_pid=$!
	sleep 1
	note "SSH Tunnel running at PID $tunnel_pid"
}

build_ssh_tunnel_teardown()
{
	kill $tunnel_pid
	note "Killed SSH Tunnel running at PID $tunnel_pid"
}

