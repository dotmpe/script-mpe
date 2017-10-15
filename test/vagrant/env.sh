#!/bin/sh

#
# This env is used by `Htd run` to setup script env, after loading package.yml
# There is no name for the env yet, but it is possible to setup your own scheme
# using package_id, package_env, package_cwd etc. but also integrating it with
# your own boxes, services, domain etc.
#

test -e ~/.local/etc/$package_id.sh && {
	. ~/.local/etc/$package_id.sh
}

test -e ~/.local/etc/profile.sh && {
	. ~/.local/etc/profile.sh
}

test -e ~/.local/etc/private-env.sh && {
	. ~/.local/etc/private-env.sh
}


#export VAGRANT_CWD=test/vagrant
export VAGRANT_NAME=script-mpe-test


case "$(whoami)@$(hostname -s)" in

	vagrant@ )
			test -n "$ENV_NAME" || export ENV_NAME=$package_id
		;;

	* )
		;;

esac


case "$ENV_NAME" in

  script-mpe-test-vbox )
		;;

	* )
		;;

esac


