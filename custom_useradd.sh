#!/bin/bash

custom-useradd () {
  #usage: custom-useradd [home directory] [username]
  #Note: do not include /home/ in the home directory, it assumes: /home/${DIRECTORY}/${USER}
  DIRECTORY=$1
  USER=$2
  PASSWORD=$(date +%s | sha256sum | base64 | head -c 8; echo)
  mkdir -p /home/${DIRECTORY}/${USER}
  useradd -s /bin/bash -d /home/${DIRECTORY}/${USER} ${USER}
  echo "${PASSWORD}" | passwd "${USER}" --stdin
  chown ${USER}:${USER} /home/${DIRECTORY}/${USER}
  chmod 755 /home/${DIRECTORY}/${USER}
  echo "********************"
  echo ">> Username: ${USER}"
  echo ">> Password: ${PASSWORD}"
  echo ">> Home Directory: /home/${DIRECTORY}/${USER}"
  echo "********************"
  sleep 1  ## used date to generate password, this assures the password will be different
}
