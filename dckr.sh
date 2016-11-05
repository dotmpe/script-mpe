#!/bin/sh
dckr__source=$_

set -e

version=0.0.2 # script-mpe



dckr_man_1__edit_main="Edit main scriptfiles. "
dckr_spc__edit_main="-E|edit-main"
dckr__edit_main()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $fn
}
dckr_als___E=edit-main


dckr_man_1__edit_local="Edit project files. "
dckr_spc__edit_main="-e|edit-local"
dckr__edit_local()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  local dckr_local=$DCKR_CONF/local.sh
  note "invoking $EDITOR $dckr_local $fn"
  $EDITOR $dckr_local $fn
}
dckr_als___e=edit-local


dckr_man_1__alias="Show bash aliases for this script."
dckr__alias()
{
  grep '\<'$scriptname'\>' ~/.alias | grep -v '^#' | while read _a A
  do
    a_id=$(echo $A | awk -F '=' '{print $1}')
    a_shell=$(echo $A | awk -F '=' '{print $2}')
    echo -e "   $a_id     \t$a_shell"
  done
}


dckr_man_1__ps="List processes for current project"
dckr__ps()
{
  dckr_p_ctx "$@"
  ${sudo}docker ps
}


dckr_man_1__stop="Stop container for image. "
dckr_spc__stop="stop <image-name>"
dckr__stop()
{
  dckr_p_ctx "$@"
  test -e './vars.sh' \
    && source ./vars.sh stop $@
  debug "image_name=$image_name"
  test -z "$image_name" && {
    dckr_image_argv $1
    debug "image_name=$image_name"
    shift $c
  }
  dckr_stop
}


dckr_man_1__start="Start image"
dckr__start()
{
  dckr_p_ctx "$@"
  dckr_start
}

dckr_man_1__destroy="Clean given container names. "
dckr_spc__destroy='[-f] destroy'
dckr__destroy()
{
  local f= ; test -n "$choice_force" || f="-f"
  while [ $# -gt 0 ]
  do ${sudo}docker rm $f $1 ; shift ; done
}

dckr_man_1__names="List images"
dckr__names()
{
  dckr_names
}

dckr_man_1__c="Get container ID"
dckr_spc__c="c <image-name>"
dckr__c()
{
  dckr_name=dandy-jenkins-server
  dckr_c "$@" || return $?
  echo $dckr_c
}

dckr_man_1__ip="List IP for one or all running containers."
dckr_spc__ip="ip [<image-name>]"
dckr__ip()
{
  test -n "$1" && {
    dckr_ip $1
  } || {
    dckr_names | while read dckr_name
    do
      ip=$(dckr_ip $dckr_name)
      test -z "$ip" || echo "$ip  $dckr_name "
    done
  }
}

# get image name from vars or cmdline, and start build (in current dir)
dckr_man_1__build="Do a simple docker build invocation (in cwd)"
dckr_spc__build="build [<image-name>]"
dckr__build_classic()
{
  test -z "$1" -a -e './vars.sh' \
    && source ./vars.sh \
    || dckr_image_argv $@

  test -n "$image_name" && {
    dckr_build
  } || { test -e "./build.sh" && {
    ./build.sh $@
  } }
}

# start new container for image, and (re)run initialization scripts
dckr_man_1__init="Do a standard run+init for an image. "
dckr_spc__init="init [<flags> <dckr-cmd> <image-name>]"
dckr__init()
{
  test -e './vars.sh' \
    && . ./vars.sh init $@

  # args: 1-n: dckr flags and cmd
  dckr_f_argv $@
  shift $c

  # args: n+1: override dckr (image) name
  dckr_name_argv $@ && { shift 1; }

  test -n "$dckr_f" || {
    test -e "./init.sh" && {
      dckr_f=-td
    } || {
      dckr_f=-ti
    }
  }

  dckr_c && {
    note "Already running $dckr_name: $dckr_c"
  }
  
  dckr_c -a && {
    dckr_start
  } || {
    dckr_run $@ $dckr_run_argv
  }

  test -e "./init.sh" && {
    source ./init.sh $@
  }
}

dckr__script()
{
  test -e './vars.sh' \
    && source ./vars.sh script $@

  # args: 1: override dckr (image) name
  dckr_name_argv 

  test -n "$dckr_f" || dckr_f=-td

  dckr_c && {
    note "Already running $dckr_name: $dckr_c"
  }
  
  dckr_c -a && {
    dckr_start
  } || {
    dckr_run $dckr_run_argv
  }

  srcdir=.
  test -n "$dckr_script" || {
    test -e "$1" && {
      dckr_script=$1
    } || {
      test -n "$dckr_cmd" && {
        srcdir=/tmp
        dckr_script=dckr-script.sh
        echo "$dckr_cmd" > $srcdir/$dckr_script
        chmod +x $srcdir/$dckr_script
      }  || error "No script or cmd" 1
    }
  }

  echo ${sudo}docker cp $srcdir/$dckr_script "$dckr_name":/tmp/$dckr_script
  ${sudo}docker cp $srcdir/$dckr_script $dckr_name:/tmp/$dckr_script
  echo ${sudo}docker exec -ti $dckr_name /tmp/$dckr_script
}

dckr__exec()
{
  test -z "$1" || image_name="$1"
  test -z "$2" || dckr_cmd="$@"
  ${sudo}docker exec -ti "$image_name" "$dckr_cmd"
}

dckr_man_1__register="Register a project with dckr build package metadata. "
dckr_spc__register="register <project-name>"
dckr__register()
{
  test -n "$UCONFDIR" || error "UCONFDIR" 1

  test -n "$proj_dir" || proj_dir="$HOME/project/$1" 
  test -d "$proj_dir" || error "no checkout $1" 1

  req_prog_meta "$1"
  dckr_arg_psh $1 defaults
  jsotk_package_sh_defaults $1 > $psh

  for cmd in build run  up down  stop start
  do
    dckr_script_from $1 $cmd
  done
}

dckr_load__build=p
dckr__build()
{
  dckr_load_psh "$1" build || error "Loading dckr build script" 1
  dckr_build || return $?
  note "Build done for $image_name"
}

dckr__run()
{
  local dckr_f=-dt
  dckr_load_psh "$1" run || error "Loading dckr run script" 1
  dckr_run || return $?
  note "New container for $image_name running ($dckr_name, $dckr_c)"
}

dckr__reset()
{
  dckr_load_psh "$1" reset || error "Loading dckr reset script" 1
  echo TODO dckr reset $dckr_reset_f || return $?
}





dckr_man_1__shipyard_options="Show currently available deploy help. "\
'
  ACTION: this is the action to use (deploy, upgrade, remove)
  IMAGE: this overrides the default Shipyard image
  PREFIX: prefix for container names
  SHIPYARD_ARGS: these are passed to the Shipyard controller container as controller args
  TLS_CERT_PATH: path to certs to enable TLS for Shipyard
'
dckr__shipyard_options()
{
  curl -s https://shipyard-project.com/deploy | bash -s -- -h
}

dckr_man_1__shipyard_init="Deploy Shipyard at 8080"
dckr__shipyard_init()
{
  note "Initializing VS1 Shipyard"
  local dckr_name=shipyard-rethinkdb
  dckr_p && {
    printf "Shipyard at vs1:8080 running from IP "
    dckr_ip
  } || {
    sudo bash -c ' curl -s https://shipyard-project.com/deploy | bash -s '
  }
}

dckr_man_1__shipyard_init_old="Shutdown and boot shipard at 8001"
dckr__shipyard_init_old()
{
  for dckr_name in shipyard shipyard-rethinkdb-data shipyard-rethinkdb
  do
    dckr_stop && dckr_rm || error "Error destroying $dckr_name" 1
  done

  ${sudo}docker run -it -d -l \
    --name shipyard-rethinkdb-data \
    --entrypoint /bin/bash shipyard/rethinkdb
  sleep 2

  ${sudo}docker run -it -d \
    --name shipyard-rethinkdb \
    --volumes-from shipyard-rethinkdb-data shipyard/rethinkdb
  sleep 4

  ${sudo}docker run -it -d \
    -p 8001:8080 \
    --name shipyard \
    --link shipyard-rethinkdb:rethinkdb shipyard/shipyard
}


dckr_man_1__init_cadvisor="Run cAdvisor at 8002"
dckr__init_cadvisor()
{
  ${sudo}docker run \
    --volume=/:/rootfs:ro \
    --volume=/var/run:/var/run:rw \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:ro \
    --publish=8002:8080 \
    --detach=true \
    --name=cadvisor \
    google/cadvisor:latest

# XXX -storage_driver=influxdb
}


dckr_man_1__init_sickbeard="Rebuild sickbeard at 8008"
dckr__init_sickbeard()
{
  dckr_f_argv $@
  image_name=sickbeard
  dckr_name=${pref}sickbeard
  cd ~/project/docker-sickbeard
  dckr_build && \
  dckr_rm && \
  dckr_run \
    -p 8008:8081 \
    -v $DCKR_VOL/sickbeard/data:/data:rw \
    -v $DCKR_VOL/sickbeard/config:/config:rw \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__reset_munin()
{
  dckr_f_argv $@
  image_name=munin
  dckr_name=${pref}munin
  dckr_stop && dckr_rm
}

dckr__init_munin()
{
  dckr_f_argv $@
  image_name=scalingo-munin-server
  dckr_name=${hostname}-munin-server
  test -d ~/project/docker-munin-server || {
    cd ~/project; pd enable docker-munin-server || return 1
  }
  cd ~/project/docker-munin-server
  dckr_build && dckr_stop && \
    dckr_rm && dckr__run_munin
}

dckr__stop_munin()
{
  image_name=scalingo-munin-server
  dckr_name=${hostname}-munin-server
  dckr_stop
}

dckr__run_munin()
{
  image_name=scalingo-munin-server
  dckr_name=${hostname}-munin-server
  dckr_run 
}


dckr__reset_sandbox()
{
  dckr_f_argv $@
  image_name=sandbox
  dckr_name=${pref}sandbox
  dckr_stop && dckr_rm
}

dckr__init_sandbox()
{
  dckr_f_argv $@
  image_name=sandbox-mpe:latest
  dckr_name=${pref}sandbox
  cd ~/project/docker-sandbox
  git co master
  dckr_build && \
  dckr_rm && \
  dckr_run \
    -p 8004:8080 \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__init_weather()
{
  dckr_f_argv $@
  image_name=weather-mpe
  dckr_name=${pref}weather
  cd ~/project/docker-sandbox
  git co docker-weather
  dckr_build && \
  dckr_rm && \
  dckr_run \
    -p 8004:8080 \
    --link ${pref}weather:${pref}weather \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__init_graphite()
{
  dckr_f_argv $@
  image_name=dotmpe/collectd-graphite
  dckr_name=${pref}x_graphite
  cd ~/project/docker-graphite
  dckr_build && \
  dckr_rm && \
  dckr_run \
    -p 2206:22 \
    -p 8006:8080 \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__init_haproxy()
{
  dckr_f_argv $@
  image_name=haproxy:1.5
  dckr_name=${pref}x_haproxy
  dckr_rm && \
  dckr_run \
    -v $DCKR_VOL/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
    -p 8009:80 \
    -p 43309:443 \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__swarm_host()
{
  echo SWARM_HOST=$SWARM_HOST
}

dckr__init_interlock()
{
  tmp=/tmp/$(get_uuid)
  mkdir -vp $tmp
  cd $tmp
  wget https://github.com/ehazlett/interlock/raw/master/docs/examples/nginx-swarm-machine/docker-compose.yml || return $?
  docker-compose up -d interlock || return $?
  docker-compose up -d nginx || return $?
  # Example app
  docker-compose up -d app || return $?
  docker-compose logs
}

dckr__init_bind()
{
  ${sudo}docker run --name ${pref}bind -d --restart=always \
      --publish 53:53/udp --publish 10000:10000 \
      --volume $DCKR_VOL/bind:/data \
      sameersbn/bind:latest
}

dckr__init_dns()
{
  dckr_f_argv $@
  image_name=quay.io/jpillora/dnsmasq-gui:latest
  dckr_name=${pref}dns
  cd ~/project/docker-dnsmasq
  dckr_build && \
  dckr_rm && \
  dckr_run \
    -p 53:53/udp \
    -p 8010:8080 \
    -v $DCKR_VOL/dnsmasq/dnsmasq.conf:/etc/dnsmasq.conf
}

dckr_man_1__dnsmasq_conf="dnsmasq static address config using image-name as hostname"
dckr__dnsmasq_conf()
{
  #prefix=
  #suffix=
  dckr__ip | while read ip name
  do
    name=${name:1}
    echo "address=/$prefix$name$suffix/$ip"
  done
}

# XXX reload is not working
dckr__dnsmasq_update()
{
  cp $DCKR_VOL/dnsmasq/dnsmasq.conf.default $DCKR_VOL/dnsmasq/dnsmasq.conf
  dckr__dnsmasq_conf >> $DCKR_VOL/dnsmasq/dnsmasq.conf
  image_name=${pref}dns
  dckr_c
  ${sudo}docker exec -i $dckr_c /opt/reload
}


dckr__init_jessie()
{
  dckr_f_argv $@
  image_name=debian:jessie
  dckr_name=${pref}jessie
  dckr_rm && \
  dckr_run
}

dckr__init_ubuntu()
{
  dckr_f_argv $@
  image_name=ubuntu:14.04
  dckr_name=${pref}ubuntu
  dckr_rm && \
  dckr_run
}

dckr__init_dev()
{
  dckr_f_argv $@
  image_name=docker-dev
  dckr_name=${pref}dev
  cd ~/project/docker-dev
  dckr_build && \
  dckr_rm && \
  dckr_run
}

# OpenWRT

# could import from tar
dckr__import_openwrt()
{
  ${sudo}docker import \
    http://downloads.openwrt.org/attitude_adjustment/12.09/x86/generic/openwrt-x86-generic-rootfs.tar.gz \
    openwrt-x86-generic-rootfs
}

dckr__config_openwrt()
{
  image_name=jessie-openwrt
  dckr_cmd="make -C /src/openwrt/openwrt menuconfig"
  dckr_f="-ti"
  dckr_run \
    -v /src/openwrt:/src/openwrt \
    -u builder
}

dckr__build_openwrt()
{
  image_name=jessie-openwrt
  dckr_cmd="make -C /src/openwrt/openwrt -j3"
  dckr_f="-ti"
  dckr_run \
    -v /src/openwrt:/src/openwrt \
    -u builder
}


dckr__init_gitlab_docker()
{
  dckr_f_argv $@
  image_name=sameersbn/gitlab:latest
  dckr_name=${pref}gitlab
  #docker pull sameersbn/gitlab:latest
  dckr_run \
    -p 8011:8080 \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

dckr__init_gitlab()
{
  ~/.conf/dckr/gitlab
  docker-compose up
}


dckr__init_redmine()
{
  cd $HOME/project/docker-redmine

  #redmine_image="$(jsotk.py yaml2json docker-compose.yml | jsotk.py path - redmine.image)"
  #test -n "$redmine_image" || redmine_image=sameersbn/redmine:3.2.1-2
  #docker pull $redmine_image

  #wget https://raw.githubusercontent.com/sameersbn/docker-redmine/master/docker-compose.yml
  #docker-compose up

  mkdir -vp $DCKR_VOL/redmine{,-postgresql}

  mkdir -vp $DCKR_VOL/redmine/plugins

  test -d $DCKR_VOL/redmine/plugins/recurring_tasks || \
    git clone https://github.com/nutso/redmine-plugin-recurring-tasks.git $DCKR_VOL/redmine/plugins/recurring_tasks

  mkdir -vp $DCKR_VOL/redmine/themes
  test -d $DCKR_VOL/redmine/themes/gitmike || \
    git clone https://github.com/makotokw/redmine-theme-gitmike.git $DCKR_VOL/redmine/themes/gitmike

  docker-compose up
}

# Setup correct IP's in host
# exit 1 on error, 2 on updated, 0 on no-op
dckr__machine_ip_update()
{
  test -n "$1" || set -- "dev"
  test "$(docker-machine status $1)" = "Running" \
    || note "Not running: docker machine $1" 1
  docker_machine_ip=$(docker-machine ip $1)
  case "$1" in
    prod )
      docker_domain=docker.simza.lan
      ;;
    * )
      docker_domain=docker-$1.simza.lan
      ;;
  esac
  grep -q '^'$docker_machine_ip'\ *'$docker_domain'$' /etc/hosts && {
    note "IP for '$1' ($docker_domain) still '$docker_machine_ip'"  
    return 0
  } || {
    sudo sed -i.bak 's/^[0-9\.]*\ \ *'$docker_domain'$/'$docker_machine_ip'   '$docker_domain'/' /etc/hosts \
      && warn "Updated IP ($docker_machine_ip) for '$1' ($docker_domain)" 2 \
      || error "Unable to upate IP ($docker_machine_ip) for '$1' ($docker_domain)" 1
  }
}

# Add NFS export entry for docker share
dckr__machines_nfs()
{
  test -n "$1" || set -- $(docker-machine ls -q)
  local updated=/tmp/dckr-machines-nfs-$(htd uuid)
  while test -n "$1"
  do
    test "$(docker-machine status $1)" = "Running" || { 
      note "Cannot updated offline box '$1'"; shift; continue; }
    note "Updating NFS for '$1' ..."
    docker-machine-nfs "$1" \
        --shared-folder=$DCKR_VOL \
        --shared-folder=$HOME \
        --shared-folder=/opt/ \
        --shared-folder=/Volumes/Simza/project \
        --nfs-config="-alldirs -mapall=501:20" \
        --force \
      && note "Reinitialized NFS for '$1'" \
      || { note "Error in NFS init for '$1'"; echo $1>$updated; } \

        #--nfs-config="-maproot=0 -alldirs -mapall=\$(id -u):\$(id -g)"

    shift
  done
  test ! -e "$updated" || {
    machines="$(echo "$(cat $updated)")"
    rm $updated
    error "Failures on (some) machines: $machines" 1
  }
}

# return 1 on error, 2 on updated, 0 on no-op
dckr__machines()
{
  test -n "$1" || set -- $(docker-machine ls -q)
  local updated=/tmp/dckr-machines-ip-updated-$(htd uuid)
  test ! -e "$updated" || rm $updated
  test -e /etc/exports || sudo touch /etc/exports
  while test -n "$1"
  do
    test "$(docker-machine status $1)" = "Running" || { shift; continue; }
    note "Updating '$1' ..."
    dckr machine-ip-update $1 || {
      case "$R" in 1 ) return 1;; 2 ) echo $1>$updated ;; esac
    }
    grep -qF $(docker-machine ip $1) /etc/exports || {
      echo "$1">$updated
    }
    shift
  done
  test ! -e "$updated" || {
    cat $updated
    machines="$(echo "$(cat $updated)")"
    rm $updated
    warn "Updates found: $machines"
    # XXX: maybe better check with u-c before removing, not needed for now
    # see also sudoers rules 
    test ! -e /etc/exports || sudo rm /etc/exports
    #test -e /etc/exports || sudo touch /etc/exports
  }
  test -e "/etc/exports" || {
    note "Updating NFS for all running machines" #'$machines'"
    dckr machines-nfs $machines || return 1
    return 2
  }
}

dckr__cleanup_all()
{
  used_space_before="$(df --sync --output=used / | tail -n 1)"

	log "Scanning for dead containers..."
	containers="$( docker ps --filter status=dead --filter status=exited -aq )"
	test -z "$dckr_cs" || {
    log "Ready to remove dead, exited containers? : $dckr_cs"
    read confirm
    trueish "$confirm" && {
      docker rm -v $dckr_cs
    }
  }
			
	log "Scanning for untagged images..."
	images="$( docker images --no-trunc | grep '<none>' | awk '{ print $3 }' )"
	test -z "$images" || {
    log "Ready to remove images? : $images"
    read confirm
    trueish "$confirm" && {
      docker rmi $images
    } || warn "Skipped rmi" 
  }

  log "Scanning for old volumes..."

  # Get mounts for running containers
  mounts=/tmp/dckr-mounts

  test -z "$(docker ps -aq)" && {
    log "No containers, nothing further to do"
    return
  } || {

    docker ps -aq | xargs docker inspect \
        | jq -r '.[] | .Mounts | .[] | .Name | select(.)' > $mounts
  }

  test -s "$mounts" && {
    log "Ready to remove unused volumes? (/var/lib/docker/volumes/* not in $mounts) "
    read confirm
    trueish "$confirm" || warn "Cancelled" 1
  } || return

  # Remove volumes not mounted in running containers
  test -n "$DOCKER_MACHINE_NAME" && {

    volumes=$( test -s "$mount" && \
      docker-machine ssh dev \
        sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d \
        | grep -vFf $mounts || \
      docker-machine ssh dev \
        sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d )

    docker-machine ssh dev sudo rm -rf $volumes

  } || {

    volumes=$( test -s "$mount" && \
      sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d \
        | grep -vFf $mounts || \
      sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d )

    sudo rm -rf $volumes
  }

  used_space_after="$(df --sync --output=used / | tail -n 1)"

  #log "Freed $(( $(( $used_space_before - $used_space_after )) / 1024 )) kb"
  log "Freed $(( $(( $used_space_before - $used_space_after )) / 1048576 )) Mb"
}


dckr__vbox()
{
  test -n "$DCKR_CONF" || error dckr-conf 1
  test -d "$DCKR_CONF" || error dckr-conf 2

  mkdir -vp $DCKR_CONF/ubuntu-trusty64-docker
  cd $DCKR_CONF/ubuntu-trusty64-docker

  vagrant init williamyeh/ubuntu-trusty64-docker
  vagrant up --provider virtualbox
}




# Lib

# Get project/running container context
dckr_p_ctx()
{
  dckr_arg_psh $1 defaults
  test -e "$HOME/project/$1/package.yml"
  req_proj_meta
  jsotk_package_sh_defaults $proj_meta  > $psh
}

dckr_p_arg()
{
  test -n "$1" || set -- '*'
  set -- "$(normalize_relative "$go_to_before/$1")"
  dckr_p_arg "$@"
}


req_proj_meta()
{
  test -n "$proj_meta" || proj_meta="$(echo $HOME/project/$1/package.y*ml | cut -d' ' -f1)"
  test -e "$proj_meta" || error "no checkout $1" 1
}

# replace with dckr_p_ctx
# Find container ID for name, or image-name (+tag)
dckr_c()
{
  test -n "$ps_f"|| ps_f=-a
  test -n "$2" && {
    local name="$2" tag=
    test -z "$3" || name=$2:$3
    dckr_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Image}}' | 
        grep '\ '$name'$' | cut -f1 -d' ')
  } || {
    req_vars dckr_name
    dckr_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Names}}' | 
        grep '\ '$dckr_name'$' | cut -f1 -d' ')
  }
  test -n "$dckr_c" || return 1
}

# Return true if running
dckr_p()
{
  ${sudo}docker ps | grep -q '\<'$dckr_name'\>' || return 1
}

dckr_load_psh()
{
  local psh=
  dckr_arg_psh "$1" "$2" || return $?
  test -e "$psh" || error "no dckr $2 registered for $1" 1
  cd ~/project/$1 || error "no dir for $1" 1
  . $psh || return $?
}

dckr_arg_psh()
{
  test -n "$1" || error "project name expected" 1
  psh=$UCONFDIR/dckr/$1/$2.sh
  mkdir -vp $(dirname $psh)
}

dckr_script_from()
{
  local psh; dckr_arg_psh "$@" || return 4?
  req_vars proj_meta psh
  test $proj_meta -ot $psh || {
    dckr_package_cmd_f_to_sh $proj_meta $2 > $psh
    log "Regenerated $psh"
  }
}

req_vars()
{
  local v=
  while test -n "$1"
  do
    v="$(eval echo \$$1)"
    test -n "$v" || error $1 $?
  done
}

dckr_package_cmd_f_to_sh()
{
  test -n "$1" || set -- package.yaml
  test -n "$2" || set -- "$1" run
  jsotk_package_sh_defaults $1
  echo "dckr_${2}_f=\\"
  jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.dckr.'$2'_f]' \
    | grep -v '^\s*$' | sed 's/^__[0-9]*="/    /' | sed 's/"$/ \\/g'
  echo "    \$dckr_${2}_f"
}



# Docker

dckr_man_1_redock=\
'
  If container is running, leave image unless forced. Otherwise delete
  for rebuild. Then build and run image. Finish with ps line and IP address.
'
dckr_spc_redock='redock <image-name> <dckr-name> [<tag>=latest]'
dckr_redock()
{
  local reset= image_name= dckr_name= tag=

  dckr_rebuild "$@"

  # Run if needed and stat
  ${sudo}docker ps -a | grep -q '\<'$dckr_name'\>' && {
    test -z "$reset" || error "still running? $dckr_name" 3
  } || {
    ${sudo}docker run -dt --name $dckr_name \
      $image_name:${tag}
  }

  echo "$dckr_name proc: "
  ${sudo}docker ps -a | grep '\<'$dckr_name'\>'
  dckr ip $dckr_name
}

dckr_rebuild()
{
  test -z "$choice_force" || reset=1
  # TODO: rebuild
}

dckr_build()
{
  test -n "$image_name" || error "$image_name" $?
  test -n "$dckrfile_dir" || dckrfile_dir=.
  ${sudo}docker build -t $image_name $dckr_build_f $dckrfile_dir || return $?
  return $?
}

dckr_run()
{
  # default flags: start daemon w/ tty
  test -n "$dckr_f" || dckr_f=-dt

  # pass container env script if set, or exists in default location
  test -n "$dckr_env" || dckr_env=$DCKR_CONF/$dckr_name-env.sh
  test -e "$dckr_env" && \
    dckr_f="$dckr_f --env-file $dckr_env"
  test -e "$proj_dir/env.sh" && \
    dckr_f="$dckr_f --env-file $proj_dir/env.sh"

  # pass hostname if set
  test -z "$dckr_hostname" || \
    dckr_f="$dckr_f --hostname $dckr_hostname"

  test -n "$dckr_name" || error dckr_name 1

  ${sudo}docker run $dckr_f $@ \
    --name $dckr_name \
    --env DCKR_NAME=$dckr_name \
    --env DCKR_IMAGE=$image_name \
    --env DCKR_CMD="$dckr_cmd" \
    $dckr_argv \
    $image_name \
    $dckr_cmd

  return $?
}

dckr_start()
{
  req_vars dckr_c
  echo "Startng container $dckr_c:"
  ${sudo}docker start $dckr_c || return $?
}

dckr_stop()
{
  test -n "$dckr_c" && {
    info "Stopping container $dckr_c:"
    ${sudo}docker stop $dckr_c
    return
  }
  test -z "$dckr_name" && {
    test -z "$image_name" || {
      info "Looking for running container by image-name $image_name:"
      dckr_c
      info "Stopping container by image-name $image_name:"
      ${sudo}docker stop $dckr_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps | grep -q '\<'$dckr_name'\>' && {
      info "Stopping container by container-name $dckr_name:"
      ${sudo}docker stop $dckr_name
    } || noop
  }
}

# remove container (with name or for image-name)
dckr_rm()
{
  test -n "$dckr_c" && {
    note "Removing container $dckr_c:"
    ${sudo}docker rm $dckr_c
    return
  }
  test -z "$dckr_name" && {
    test -z "$image_name" || {
      debug "Looking for container by image-name $image_name:"
      dckr_c -a
      info "Removing container $dckr_c"
      ${sudo}docker rm $dckr_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps -a | grep -q '\<'$dckr_name'\>' && {
      info "Removing container by container-name $dckr_name:"
      ${sudo}docker rm $dckr_name
    } || noop
  }
}

dckr_names()
{
  ${sudo}docker inspect --format='{{.Name}}' $(${sudo}docker ps -aq --no-trunc)
}

dckr_ip()
{
  test -n "$1" || set -- $dckr_c
  test -n "$1" || set -- $dckr_name
  test -n "$1" || error "dckr-ip: container required" 1
  ${sudo}docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1 \
    || error "docker IP inspect on $1 failed" 1
}

# gobble up flags and set $dckr_f, and/or set and return $dckr_cmd upon first arg.
# $c is the amount of arguments consumed
dckr_f_argv()
{
  c=0
  while test -n "$1"
  do
    test -z "$1" || {
      test "${1:0:1}" = "-" && {
        dckr_f="$dckr_f $1"
      } || {
        dckr_cmd="$1"
        c=$(( $c + 1 ))
        return
      }
    }
    c=$(( $c + 1 )) && shift 1
  done
}

dckr_name_argv()
{
  test -z "$1" && {
    # dont override without CLI args, only set
    test -n "$dckr_name" && return 1;
  }
  test -z "$1" && name=$(basename $(pwd)) || name=$1
  dckr_name=${pref}${name}
_ test -n "$1" || info "Using dir for dckr-name: $dckr_name"
}

dckr_image_argv()
{
  test -z "$1" && error "Must enter image name or tag" 1 || tag=$1
  c=1
  image_name=${tag}
}



# include private projects
test ! -e $DCKR_CONF/local.sh || {
  . $DCKR_CONF/local.sh
}





### Main


dckr_main()
{
  test -n "$scriptdir" || scriptdir="$(cd "$(dirname "$0")"; pwd -P)"
  dckr_init || return 0

  local scriptname=dckr base=$(basename $0 .sh) verbosity=5

  case "$base" in $scriptname )

      dckr_lib || exit $?

      # Execute
      run_subcmd "$@" || exit $?
      ;;

  esac
}

dckr_init()
{
  test -z "$BOX_INIT" || return 1
  test -n "$scriptdir"
  export SCRIPTPATH=$scriptdir
  . $scriptdir/util.sh
  util_init
  . $scriptdir/box.init.sh
  . $scriptdir/box.lib.sh
  box_run_sh_test
  . $scriptdir/main.lib.sh
  . $scriptdir/main.init.sh
  . $scriptdir/util.sh
  . $scriptdir/projectdir.lib.sh
}

dckr_lib()
{
  # -- dckr box lib sentinel --
  set --
}

dckr_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$DCKR_CONF" || DCKR_CONF=$UCONFDIR/dckr
  test -n "$DCKR_VOL" || DCKR_VOL=/Volumes/dckr

  test -e "$DCKR_CONF" || error "Missing docker config dir $DCKR_CONF" 1
  test -e "$DCKR_VOL" || error "Missing docker volumes dir $DCKR_VOL" 1

  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__')"
  dckr_c_pref="${hostname}-"

  test -n "$EDITOR" || EDITOR=vim
  # -- dckr box load sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  case "$1" in load-ext ) ;; * )
    dckr_main "$@"
  ;; esac
;; esac

