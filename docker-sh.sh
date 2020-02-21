#!/bin/sh
docker_sh__source=$_

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

docker_sh_man_1__ps="List processes for current project"
docker_sh__ps()
{
  docker_sh_p_ctx "$@"
  ${sudo}docker ps
}
docker_sh_als__list_info=ps
docker_sh_als__details=ps
docker_sh_als__update=ps
docker_sh_als__list=ps
docker_sh_als__global_status=ps


docker_sh_man_1__stop="Stop container for image. "
docker_sh_spc__stop="stop <image-name>"
docker_sh__stop()
{
  docker_sh_p_ctx "$@"
  test -e './vars.sh' \
    && source ./vars.sh stop $@
  debug "image_name=$image_name"
  test -z "$image_name" && {
    docker_sh_image_argv $1
    debug "image_name=$image_name"
    shift $c
  }
  docker_sh_stop
}


docker_sh_man_1__start="Start image"
docker_sh__start()
{
  docker_sh_p_ctx "$@"
  docker_sh_start
}

docker_sh_man_1__destroy="Clean given container names. "
docker_sh_spc__destroy='[-f] destroy'
docker_sh__destroy()
{
  local f= ; test -n "$choice_force" || f="-f"
  while [ $# -gt 0 ]
  do ${sudo}docker rm $f $1 ; shift ; done
}

docker_sh_man_1__names="List images"
docker_sh__names()
{
  docker_sh_names
}

docker_sh_man_1__c="Get container ID"
docker_sh_spc__c="c <image-name>"
docker_sh__c()
{
  docker_name=dandy-jenkins-server
  docker_sh_c "$@" || return $?
  echo $docker_sh_c
}

docker_sh_man_1__port="List exposed port for SSH for one or all running containers."
docker_sh_spc__port="port [<PORT>] [<image-name>]"
docker_sh__port()
{
  echo "$1" | grep -q '^[0-9][0-9]*$' && {
    docker_sh_c_port=$1 ; shift
  } || {
    docker_sh_c_port=22
  }
  test -n "$1" && {
    docker_sh_c_port $1
  } || {
    docker_sh_names | while read docker_name
    do
      port=$(docker_sh_c_port $docker_name)
      test -z "$port" || echo "$port  $docker_name "
    done
  }
}

docker_sh_man_1__ip="List IP for one or all running containers."
docker_sh_spc__ip="ip [<image-name>]"
docker_sh__ip()
{
  test -n "$1" && {
    docker_sh_c_ip $1
  } || {
    docker_sh_names | while read docker_name
    do
      ip=$(docker_sh_c_ip $docker_name)
      test -z "$ip" || echo "$ip  $docker_name "
    done
  }
}

# get image name from vars or cmdline, and start build (in current dir)
docker_sh_man_1__build="Do a simple docker build invocation (in cwd)"
docker_sh_spc__build="build [<image-name>]"
docker_sh__build_classic()
{
  test -z "$1" -a -e './vars.sh' \
    && source ./vars.sh \
    || docker_sh_image_argv $@

  test -n "$image_name" && {
    docker_sh_build
  } || { test -e "./build.sh" && {
    ./build.sh $@
  } }
}

# start new container for image, and (re)run initialization scripts
docker_sh_man_1__init="Do a standard run+init for an image. "
docker_sh_spc__init="init [<flags> <dckr-cmd> <image-name>]"
docker_sh__init()
{
  test -e './vars.sh' \
    && . ./vars.sh init $@

  # args: 1-n: dckr flags and cmd
  docker_sh_f_argv $@
  shift $c

  # args: n+1: override dckr (image) name
  docker_sh_name_argv $@ && { shift 1; }

  test -n "$docker_sh_f" || {
    test -e "./init.sh" && {
      docker_sh_f=-td
    } || {
      docker_sh_f=-ti
    }
  }

  docker_sh_c && {
    note "Already running $docker_name: $docker_sh_c"
  }

  docker_sh_c -a && {
    docker_sh_start
  } || {
    docker_sh_run $@ $docker_sh_run_argv
  }

  test -e "./init.sh" && {
    source ./init.sh $@
  }
}

docker_sh__script()
{
  test -e './vars.sh' \
    && source ./vars.sh script $@

  # args: 1: override dckr (image) name
  docker_sh_name_argv

  test -n "$docker_sh_f" || docker_sh_f=-td

  docker_sh_c && {
    note "Already running $docker_name: $docker_sh_c"
  }

  docker_sh_c -a && {
    docker_sh_start
  } || {
    docker_sh_run $docker_sh_run_argv
  }

  srcdir=.
  test -n "$docker_sh_script" || {
    test -e "$1" && {
      docker_sh_script=$1
    } || {
      test -n "$docker_cmd" && {
        srcdir=/tmp
        docker_sh_script=dckr-script.sh
        echo "$docker_cmd" > $srcdir/$docker_sh_script
        chmod +x $srcdir/$docker_sh_script
      }  || error "No script or cmd" 1
    }
  }

  echo ${sudo}docker cp $srcdir/$docker_sh_script "$docker_name":/tmp/$docker_sh_script
  ${sudo}docker cp $srcdir/$docker_sh_script $docker_name:/tmp/$docker_sh_script
  echo ${sudo}docker exec -ti $docker_name /tmp/$docker_sh_script
}

docker_sh__exec()
{
  test -z "$1" || image_name="$1"
  test -z "$2" || docker_cmd="$@"
  ${sudo}docker exec -ti "$image_name" "$docker_cmd"
}

docker_sh_man_1__register="Register a project with dckr build package metadata. "
docker_sh_spc__register="register <project-name>"
docker_sh__register()
{
  test -n "$UCONFDIR" || error "UCONFDIR" 1

  test -n "$proj_dir" || proj_dir="$HOME/project/$1"
  test -d "$proj_dir" || error "no checkout $1" 1

  req_prog_meta "$1"
  docker_sh_arg_psh $1 defaults
  jsotk_package_sh_defaults $1 > $psh

  for cmd in build run  up down  stop start
  do
    docker_sh_script_from $1 $cmd
  done
}

docker_sh_load__build=p
docker_sh__build()
{
  docker_sh_load_psh "$1" build || error "Loading dckr build script" 1
  docker_sh_build || return $?
  note "Build done for $image_name"
}

docker_sh__run()
{
  local docker_sh_f=-dt
  docker_sh_load_psh "$1" run || error "Loading dckr run script" 1
  docker_sh_run || return $?
  note "New container for $image_name running ($docker_name, $docker_sh_c)"
}

docker_sh__reset()
{
  docker_sh_load_psh "$1" reset || error "Loading dckr reset script" 1
  echo TODO dckr reset $docker_sh_reset_f || return $?
}





docker_sh_man_1__shipyard_options="Show currently available deploy help. "\
'
  ACTION: this is the action to use (deploy, upgrade, remove)
  IMAGE: this overrides the default Shipyard image
  PREFIX: prefix for container names
  SHIPYARD_ARGS: these are passed to the Shipyard controller container as controller args
  TLS_CERT_PATH: path to certs to enable TLS for Shipyard
'
docker_sh__shipyard_options()
{
  curl -s https://shipyard-project.com/deploy | bash -s -- -h
}

docker_sh_man_1__shipyard_init="Deploy Shipyard at 8080"
docker_sh__shipyard_init()
{
  note "Initializing VS1 Shipyard"
  local docker_name=shipyard-rethinkdb
  docker_sh_p && {
    printf "Shipyard at vs1:8080 running from IP "
    docker_sh_c_ip
  } || {
    sudo bash -c ' curl -s https://shipyard-project.com/deploy | bash -s '
  }
}

docker_sh_man_1__shipyard_init_old="Shutdown and boot shipard at 8001"
docker_sh__shipyard_init_old()
{
  for docker_name in shipyard shipyard-rethinkdb-data shipyard-rethinkdb
  do
    docker_sh_stop && docker_sh_rm || error "Error destroying $docker_name" 1
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


docker_sh_man_1__init_cadvisor="Run cAdvisor at 8002"
docker_sh__init_cadvisor()
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


docker_sh_man_1__init_sickbeard="Rebuild sickbeard at 8008"
docker_sh__init_sickbeard()
{
  docker_sh_f_argv $@
  image_name=sickbeard
  docker_name=${pref}sickbeard
  cd ~/project/docker-sickbeard
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run \
    -p 8008:8081 \
    -v $DCKR_VOL/sickbeard/data:/data:rw \
    -v $DCKR_VOL/sickbeard/config:/config:rw \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__reset_sandbox()
{
  docker_sh_f_argv $@
  image_name=sandbox
  docker_name=${pref}sandbox
  docker_sh_stop && docker_sh_rm
}

docker_sh__init_sandbox()
{
  docker_sh_f_argv $@
  image_name=sandbox-mpe:latest
  docker_name=${pref}sandbox
  cd ~/project/docker-sandbox
  git co master
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run \
    -p 8004:8080 \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__init_weather()
{
  docker_sh_f_argv $@
  image_name=weather-mpe
  docker_name=${pref}weather
  cd ~/project/docker-sandbox
  git co docker-weather
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run \
    -p 8004:8080 \
    --link ${pref}weather:${pref}weather \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__init_graphite()
{
  docker_sh_f_argv $@
  image_name=dotmpe/collectd-graphite
  docker_name=${pref}x_graphite
  cd ~/project/docker-graphite
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run \
    -p 2206:22 \
    -p 8006:8080 \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__init_haproxy()
{
  docker_sh_f_argv $@
  image_name=haproxy:1.5
  docker_name=${pref}x_haproxy
  docker_sh_rm && \
  docker_sh_run \
    -v $DCKR_VOL/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
    -p 8009:80 \
    -p 43309:443 \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__swarm_host()
{
  echo SWARM_HOST=$SWARM_HOST
}

docker_sh__init_interlock()
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

docker_sh__init_bind()
{
  ${sudo}docker run --name ${pref}bind -d --restart=always \
      --publish 53:53/udp --publish 10000:10000 \
      --volume $DCKR_VOL/bind:/data \
      sameersbn/bind:latest
}

docker_sh__init_dns()
{
  docker_sh_f_argv $@
  image_name=quay.io/jpillora/dnsmasq-gui:latest
  docker_name=${pref}dns
  cd ~/project/docker-dnsmasq
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run \
    -p 53:53/udp \
    -p 8010:8080 \
    -v $DCKR_VOL/dnsmasq/dnsmasq.conf:/etc/dnsmasq.conf
}

docker_sh_man_1__dnsmasq_conf="dnsmasq static address config using image-name as hostname"
docker_sh__dnsmasq_conf()
{
  #prefix=
  #suffix=
  docker_sh__ip | while read ip name
  do
    name=${name:1}
    echo "address=/$prefix$name$suffix/$ip"
  done
}

# XXX reload is not working
docker_sh__dnsmasq_update()
{
  cp $DCKR_VOL/dnsmasq/dnsmasq.conf.default $DCKR_VOL/dnsmasq/dnsmasq.conf
  docker_sh__dnsmasq_conf >> $DCKR_VOL/dnsmasq/dnsmasq.conf
  image_name=${pref}dns
  docker_sh_c
  ${sudo}docker exec -i $docker_sh_c /opt/reload
}


docker_sh__init_jessie()
{
  docker_sh_f_argv $@
  image_name=debian:jessie
  docker_name=${pref}jessie
  docker_sh_rm && \
  docker_sh_run
}

docker_sh__init_ubuntu()
{
  docker_sh_f_argv $@
  image_name=ubuntu:14.04
  docker_name=${pref}ubuntu
  docker_sh_rm && \
  docker_sh_run
}

docker_sh__init_dev()
{
  docker_sh_f_argv $@
  image_name=docker-dev
  docker_name=${pref}dev
  cd ~/project/docker-dev
  docker_sh_build && \
  docker_sh_rm && \
  docker_sh_run
}


# OpenWRT compile tool-chain

# could import from tar
docker_sh__import_openwrt()
{
  ${sudo}docker import \
    http://downloads.openwrt.org/attitude_adjustment/12.09/x86/generic/openwrt-x86-generic-rootfs.tar.gz \
    openwrt-x86-generic-rootfs
}

docker_sh__config_openwrt()
{
  image_name=jessie-openwrt
  docker_cmd="make -C /src/openwrt/openwrt menuconfig"
  docker_sh_f="-ti"
  docker_sh_run \
    -v /src/openwrt:/src/openwrt \
    -u builder
}

docker_sh__build_openwrt()
{
  image_name=jessie-openwrt
  docker_cmd="make -C /src/openwrt/openwrt -j3"
  docker_sh_f="-ti"
  docker_sh_run \
    -v /src/openwrt:/src/openwrt \
    -u builder
}


# MySQL
docker_sh__mysql()
{
  #req_profile dckr-mysql \
  export \
      db_ext_port=3306 \
      docker_name=$(whoami)-mysql \
      db_name=data \
      db_user=$(whoami) \
      image_name=mysql/mysql-server:latest \
      #db_user_passwd=$(whoami) \
      #db_root_passwd= \

  test -n "$db_user_passwd" || {
     export db_user_passwd=$(rnd_passwd 8)
     stderr note "Set random 8-char password for user '$db_user': '$db_user_passwd' (given only once)"
  }

  test -n "$db_root_passwd" || {
     export db_root_passwd=$(rnd_passwd 16)
     stderr note "Set random 16-char password for root: '$db_root_passwd' (given only once)"
  }


  test -n "$1" || set -- list
  case "$1" in

    list )
        ${dckr} ps | grep mysql ||
           warn "no mysql instances" 1
      ;;

    status )
        docker_sh_c_status >/dev/null ||
           stderr warn "Not running: '$docker_name'" 1
      ;;

    run )
        docker_sh_run \
          -p $db_ext_port:3306 \
          --env MYSQL_DATABASE=$db_name \
          --env MYSQL_ROOT_PASSWORD=$db_root_passwd \
          --env MYSQL_USER=$db_user \
          --env MYSQL_PASSWORD=$db_user_passwd \
        || return $?
      ;;

    grant-user )
        test -n "$user" || user=$db_user
        test -n "$db" || db='*'
        { cat <<EOM
GRANT ALL PRIVILEGES ON \`$db\`.* TO '$user'@'%' ;
FLUSH PRIVILEGES;
EOM
        } | ${dckr} exec -i \
                  $docker_name \
                  mysql --password="$db_root_passwd" || return $?
      ;;

    open-root-tcp )
        test -n "$db" || db='*'
        # Open up root account for non-localhost connections
        { cat <<EOM
GRANT ALL PRIVILEGES ON \`$db\`.* TO 'root'@'%' IDENTIFIED BY "$db_root_passwd";
FLUSH PRIVILEGES;
EOM
        } | ${dckr} exec -i \
                  $docker_name \
                  mysql --password="$db_root_passwd" || return $?
      ;;

    create-db )
        test -n "$db" || error "DB to create expected" 1
        test -n "$user" || user=$db_user
        { cat <<EOM
CREATE DATABASE \`$db\` CHARACTER SET utf8 COLLATE utf8_general_ci ;
GRANT ALL PRIVILEGES ON \`$db\`.* TO '$user'@'%' ;
FLUSH PRIVILEGES ;
EOM
        } | ${dckr} exec -i \
                  $docker_name \
                  mysql --password="$db_root_passwd" || return $?
      ;;

    drop-db )
        test -n "$db" || error "DB to drop expected" 1
        { cat <<EOM
DROP DATABASE \`$db\`;
EOM
        } | ${dckr} exec -i \
                  $docker_name \
                  mysql --password="$db_root_passwd" || return $?
      ;;

    wait )
        printf -- "Waiting for mysql.."
        until ${dckr} exec -i $docker_name mysql -hlocalhost -P$db_ext_port \
          -uroot -p"$db_root_passwd" -e "show databases"
        do printf "."
          sleep 2
        done 2> /dev/null
        printf -- "\nmysql ready at $ENV_NAME\n"
      ;;

    test )
         echo "SHOW TABLES;" | ${dckr} exec -i $docker_name \
           mysql $db_name -u"$db_user" -p"$db_user_passwd" || return $?
      ;;

    test-local )
         echo "SHOW TABLES;" |
           mysql $db_name -h$hostname -P$db_ext_port -u"$db_user" -p"$db_user_passwd" || return $?
      ;;

    deinit )
         ${dckr} rm -f $docker_name
      ;;

    init )
        docker_sh__mysql run || return $?
        docker_sh__mysql wait || return $?
        docker_sh__mysql open-root-tcp || return $?
        docker_sh__mysql test || return $?
      ;;

    * ) stderr error "? 'mysql $*'" 1
      ;;

  esac
}


# Project tooling

docker_sh__init_gitlab_docker()
{
  docker_sh_f_argv $@
  image_name=sameersbn/gitlab:latest
  docker_name=${pref}gitlab
  #docker pull sameersbn/gitlab:latest
  docker_sh_run \
    -p 8011:8080 \
    -v $DCKR_VOL/ssh:/docker-ssh:ro \
    -v /etc/localtime:/etc/localtime:ro
}

docker_sh__init_gitlab()
{
  ~/.conf/dckr/gitlab
  docker-compose up
}


docker_sh__init_redmine()
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



docker_sh__cleanup_all()
{
  used_space_before="$(df --sync --output=used / | tail -n 1)"

  log "Scanning for dead containers..."
  containers="$( docker ps --filter status=dead --filter status=exited -aq )"
  test -z "$docker_sh_cs" || {
    log "Ready to remove dead, exited containers? : $docker_sh_cs"
    read confirm
    trueish "$confirm" && {
      docker rm -v $docker_sh_cs
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

  volumes=$( test -s "$mount" && \
    sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d \
      | grep -vFf $mounts || \
    sudo find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d )

  sudo rm -rf $volumes

  used_space_after="$(df --sync --output=used / | tail -n 1)"

  #log "Freed $(( $(( $used_space_before - $used_space_after )) / 1024 )) kb"
  log "Freed $(( $(( $used_space_before - $used_space_after )) / 1048576 )) Mb"
}


docker_sh__vbox()
{
  test -n "$DCKR_UCONF" || error dckr-conf 1
  test -d "$DCKR_UCONF" || error dckr-conf 2

  mkdir -vp $DCKR_UCONF/ubuntu-trusty64-docker
  cd $DCKR_UCONF/ubuntu-trusty64-docker

  vagrant init williamyeh/ubuntu-trusty64-docker
  vagrant up --provider virtualbox
}




# Lib

# Get project/running container context
docker_sh_p_ctx()
{
  docker_sh_arg_psh $1 defaults
  test -e "$HOME/project/$1/package.yml" || return
  req_proj_meta
  jsotk_package_sh_defaults $proj_meta  > $psh
}

docker_sh_p_arg()
{
  test -n "$1" || set -- '*'
  set -- "$(normalize_relative "$go_to_before/$1")"
  docker_sh_p_arg "$@"
}


req_proj_meta()
{
  test -n "$proj_meta" || proj_meta="$(echo $HOME/project/$1/package.y*ml | cut -d' ' -f1)"
  test -e "$proj_meta" || error "no checkout $1" 1
}

# replace with docker_sh_p_ctx
# Find container ID for name, or image-name (+tag)
docker_sh_c()
{
  test -n "$ps_f"|| ps_f=-a
  test -n "$2" && {
    local name="$2" tag=
    test -z "$3" || name=$2:$3
    docker_sh_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Image}}' |
        grep '\ '$name'$' | cut -f1 -d' ')
  } || {
    req_vars docker_name
    docker_sh_c=$(${sudo}docker ps $ps_f --format='{{.ID}} {{.Names}}' |
        grep '\ '$docker_name'$' | cut -f1 -d' ')
  }
  test -n "$docker_sh_c" || return 1
}

# Return true if running
docker_sh_p()
{
  ${sudo}docker ps | grep -q '\<'$docker_name'\>' || return 1
}

docker_sh_load_psh()
{
  local psh=
  docker_sh_arg_psh "$1" "$2" || return $?
  test -e "$psh" || error "no dckr $2 registered for $1" 1
  cd ~/project/$1 || error "no dir for $1" 1
  . $psh || return $?
}

docker_sh_arg_psh()
{
  test -n "$1" || error "project name expected" 1
  psh=$UCONFDIR/dckr/$1/$2.sh
  mkdir -vp $(dirname $psh)
}

docker_sh_script_from()
{
  local psh; docker_sh_arg_psh "$@" || return 4?
  req_vars proj_meta psh
  test $proj_meta -ot $psh || {
    docker_sh_package_cmd_f_to_sh $proj_meta $2 > $psh
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

docker_sh_package_cmd_f_to_sh()
{
  test -n "$1" || set -- package.yaml
  test -n "$2" || set -- "$1" run
  jsotk_package_sh_defaults $1
  echo "docker_sh_${2}_f=\\"
  jsotk.py -I yaml -O fkv objectpath $1 '$..*[@.dckr.'$2'_f]' \
    | grep -v '^\s*$' | sed 's/^__[0-9]*="/    /' | sed 's/"$/ \\/g'
  echo "    \$docker_sh_${2}_f"
}



# Docker

docker_sh_man_1_redock=\
'
  If container is running, leave image unless forced. Otherwise delete
  for rebuild. Then build and run image. Finish with ps line and IP address.
'
docker_sh_spc_redock='redock <image-name> <dckr-name> [<tag>=latest]'
docker_sh_redock()
{
  local reset= image_name= docker_name= tag=

  docker_sh_rebuild "$@"

  # Run if needed and stat
  ${sudo}docker ps -a | grep -q '\<'$docker_name'\>' && {
    test -z "$reset" || error "still running? $docker_name" 3
  } || {
    ${sudo}docker run -dt --name $docker_name \
      $image_name:${tag}
  }

  echo "$docker_name proc: "
  ${sudo}docker ps -a | grep '\<'$docker_name'\>'
  docker-sh.sh ip $docker_name
}

docker_sh_rebuild()
{
  test -z "$choice_force" || reset=1
  # TODO: rebuild
}

docker_sh_build()
{
  test -n "$image_name" || error "$image_name" $?
  test -n "$docker_shfile_dir" || docker_shfile_dir=.
  ${sudo}docker build -t $image_name $docker_sh_build_f $docker_shfile_dir || return $?
  return $?
}

docker_sh_run()
{
  # default flags: start daemon w/ tty
  test -n "$docker_sh_f" || docker_sh_f=-dt

  # pass container env script if set, or exists in default location
  test -n "$docker_sh_env" || docker_sh_env=$DCKR_UCONF/$docker_name-env.sh
  test -e "$docker_sh_env" && \
    docker_sh_f="$docker_sh_f --env-file $docker_sh_env"
  test -e "$proj_dir/env.sh" && \
    docker_sh_f="$docker_sh_f --env-file $proj_dir/env.sh"

  # pass hostname if set
  test -z "$docker_sh_hostname" || \
    docker_sh_f="$docker_sh_f --hostname $docker_sh_hostname"

  test -n "$docker_name" || error docker_name 1

  ${sudo}docker run $docker_sh_f $@ \
    --name $docker_name \
    --env DCKR_NAME=$docker_name \
    --env DCKR_IMAGE=$image_name \
    --env DCKR_CMD="$docker_cmd" \
    $docker_sh_argv \
    $image_name \
    $docker_cmd

  return $?
}

docker_sh_start()
{
  req_vars docker_sh_c
  echo "Startng container $docker_sh_c:"
  ${sudo}docker start $docker_sh_c || return $?
}

docker_sh_stop()
{
  test -n "$docker_sh_c" && {
    std_info "Stopping container $docker_sh_c:"
    ${sudo}docker stop $docker_sh_c
    return
  }
  test -z "$docker_name" && {
    test -z "$image_name" || {
      std_info "Looking for running container by image-name $image_name:"
      docker_sh_c
      std_info "Stopping container by image-name $image_name:"
      ${sudo}docker stop $docker_sh_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps | grep -q '\<'$docker_name'\>' && {
      std_info "Stopping container by container-name $docker_name:"
      ${sudo}docker stop $docker_name
    } || true
  }
}

# remove container (with name or for image-name)
docker_sh_rm()
{
  test -n "$docker_sh_c" && {
    note "Removing container $docker_sh_c:"
    ${sudo}docker rm $docker_sh_c
    return
  }
  test -z "$docker_name" && {
    test -z "$image_name" || {
      debug "Looking for container by image-name $image_name:"
      docker_sh_c -a
      std_info "Removing container $docker_sh_c"
      ${sudo}docker rm $docker_sh_c
    }
  } || {
    # check for container with name and remove
    ${sudo}docker ps -a | grep -q '\<'$docker_name'\>' && {
      std_info "Removing container by container-name $docker_name:"
      ${sudo}docker rm $docker_name
    } || true
  }
}

# gobble up flags and set $docker_sh_f, and/or set and return $docker_cmd upon first arg.
# $c is the amount of arguments consumed
docker_sh_f_argv()
{
  c=0
  while test -n "$1"
  do
    test -z "$1" || {
      test "${1:0:1}" = "-" && {
        docker_sh_f="$docker_sh_f $1"
      } || {
        docker_cmd="$1"
        c=$(( $c + 1 ))
        return
      }
    }
    c=$(( $c + 1 )) && shift 1
  done
}

docker_sh_name_argv()
{
  test -z "$1" && {
    # dont override without CLI args, only set
    test -n "$docker_name" && return 1;
  }
  test -z "$1" && name=$(basename $(pwd)) || name=$1
  docker_name=${pref}${name}
_ test -n "$1" || std_info "Using dir for dckr-name: $docker_name"
}

docker_sh_image_argv()
{
  test -z "$1" && error "Must enter image name or tag" 1 || tag=$1
  c=1
  image_name=${tag}
}



# include private projects
test ! -e $DCKR_UCONF/local.sh || {
  . $DCKR_UCONF/local.sh
}



# Generic subcmd's

docker_sh_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
docker_sh_load__help=f
docker_sh_spc__help='-h|help [ID]'
docker_sh__help()
{
  (
    base=docker_sh \
    choice_global=1 \
      std__help "$@"
  )
  rm_failed || return 0
}
#docker_sh_als___h=help


docker_sh_man_1__version="Version info" # TODO: rewrite std__help to use try_value
docker_sh_man_1__version="Version info"
docker_sh__version()
{
  echo "$(cat $scriptpath/.app-id)/$version"
}
docker_sh_als__V=version


docker_sh__commands()
{
  echo " ps|list-info|details|update|list|global-status            "
  echo " details|update|list-info      "
  echo ""
  echo " init        Prepare project, env"
  echo " build       Update image"
  echo " run         Create instance"
  echo " reset       Drop instance if exist, restart from image"
  echo " clean       "
}


docker_sh_man_1__edit_main="Edit main scriptfiles. "
docker_sh_spc__edit_main="-E|edit-main"
docker_sh__edit_main()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $evoke $fn
}
docker_sh_als___E=edit-main


docker_sh_man_1__edit_local="Edit project files: local and . "
docker_sh_spc__edit_main="-e|edit-local"
docker_sh__edit_local()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  local docker_sh_local=$DCKR_UCONF/local.sh
  note "invoking $EDITOR $docker_sh_local $fn"
  $EDITOR $evoke $docker_sh_local $fn
}
docker_sh_als___e=edit-local
docker_sh_als__edit=edit-local


docker_sh_man_1__alias="Show bash aliases for this script."
docker_sh__alias()
{
  grep '\<'$scriptname'\>' ~/.alias | grep -v '^#' | while read _a A
  do
    a_id=$(echo $A | awk -F '=' '{print $1}')
    a_shell=$(echo $A | awk -F '=' '{print $2}')
    echo -e "   $a_id     \t$a_shell"
  done
}



# Script main functions

docker_sh_main()
{
  test -n "$scriptpath" || scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
  docker_sh_init || return 0

  local scriptname=docker-sh alias=dckr base=$(basename $0 .sh) verbosity=5
  local failed=

  case "$base" in $scriptname | $alias )

      test "$base" = "$alias" && base=$scriptname

      docker_sh_lib || exit $?

      # Execute
      main_run_subcmd "$@" || exit $?
      ;;

  esac
}

# FIXME: Pre-bootstrap init
docker_sh_init()
{
  test -n "$LOG" ||
    export LOG=/usr/local/share/mkdoc/Core/log.sh
  test -z "$BOX_INIT" || return 1
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  test -e /var/run/docker.sock -a -x "$(which docker)" && {
    test -w /var/run/docker.sock || sudo="sudo "
    dckr=${sudo}docker
  }
  # util_mode=ext . $scriptpath/util.sh load-ext
  CWD=$scriptpath
  . $scriptpath/tools/sh/init.sh

  lib_load $default_lib
  . $scriptpath/tools/sh/box.env.sh
  lib_load main box docker-sh
  #lib_load projectdir
  box_run_sh_test
  # -- dckr-sh box init sentinel --
}

# FIXME: 2nd boostrap init
docker_sh_lib()
{
  # -- dckr-sh box lib sentinel --
  set --
}


# Pre-exec: post subcmd-boostrap init
docker_sh_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -e "$UCONFDIR" || error "Missing user config dir $UCONFDIR" 1

  test -n "$DCKR_UCONF" || DCKR_UCONF=$UCONFDIR/dckr
  test -n "$DCKR_VOL" || DCKR_VOL=/srv/docker-volumes-local
  test -n "$DCKR_CONF" || DCKR_CONF=$DCKR_VOL/config
  test -e "$DCKR_UCONF" || error "Missing docker user config dir $DCKR_UCONF" 1
  #test -e "$DCKR_CONF" || error "Missing docker config dir $DCKR_CONF" 1
  test -e "$DCKR_VOL" || error "Missing docker volumes dir $DCKR_VOL" 1

  test -n "$SCR_ETC" || export SCR_ETC=$HOME/.local/etc

  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__')"
  docker_sh_c_pref="${hostname}-"

  test -n "$EDITOR" || EDITOR=vim
  local flags="$(try_value "${subcmd}" load | sed 's/./&\ /g')"
  for x in $flags
  do case "$x" in

    f ) # failed: set/cleanup failed varname
        export failed=$(setup_tmpf .failed)
      ;;

    esac
  done

  # -- dckr-sh box load sentinel --
  set --
}

# Post-exec: subcmd and script deinit
docker_sh_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" load | sed 's/./&\ /g')
  do case "$x" in
      f )
          clean_failed || unload_ret=1
          unset failed
        ;;
  esac; done

  unset subcmd subcmd_pref \
          def_subcmd func_exists func

  return $unload_ret
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in
    load-ext ) ;;
    * )
      docker_sh_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.4-dev docker-sh.sh
