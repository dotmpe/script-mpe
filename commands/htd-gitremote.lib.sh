#!/bin/sh

htd_man_1__gitremote='List repos at remote (for SSH), or echo remote URL.

    TODO: list
    list-for-ns Ns-Name

    TODO: hostinfo [ Remote-Name | Remote-ID ]
        Get host for given remote name or UCONF:git:remote Id.


TODO: match repositories for user/host with remote providers (SSH dirs, GIT
servers)
'

gitremote__help ()
{
  echo "$htd_man_1__gitremote"
}
