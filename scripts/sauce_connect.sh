#!/bin/bash

# MIT LICENSE
# 
# Copyright (c) 2016 Travis CI GmbH <contact@travis-ci.org>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# As implied above, this script is from
# https://github.com/travis-ci/travis-build/blob/179a5072eade5e0202a08b3ede6e285d962f5f24/lib/travis/build/addons/sauce_connect/templates/sauce_connect.sh
# The primary difference between this file and that is you can run this script
# directly instead of sourcing it into your shell.

export _SC_PID=unset

function travis_start_sauce_connect() {
  if [ -z "${SAUCE_USERNAME}" ] || [ -z "${SAUCE_ACCESS_KEY}" ]; then
      echo "This script can't run without your Sauce credentials"
      echo "Please set SAUCE_USERNAME and SAUCE_ACCESS_KEY env variables"
      echo "export SAUCE_USERNAME=ur-username"
      echo "export SAUCE_ACCESS_KEY=ur-access-key"
      return 1
  fi

  local sc_tmp sc_platform sc_distro sc_distro_fmt sc_distro_shasum \
    sc_readyfile sc_logfile sc_dir sc_tunnel_id_arg sc_actual_shasum

  sc_tmp="$(mktemp -d -t sc.XXXX)"
  echo "Using temp dir $sc_tmp"
  pushd $sc_tmp

  sc_platform=$(uname | sed -e 's/Darwin/osx/' -e 's/Linux/linux/')
  case "${sc_platform}" in
      linux)
          sc_distro_fmt=tar.gz
          sc_distro_shasum=42edb8dc5356916fe7b08c0d85144a067d8f4475;;
      osx)
          sc_distro_fmt=zip
          sc_distro_shasum=4a25a0f6975b74719621fdd9e646edd08cbf2434;;
  esac
  sc_distro=sc-4.3.16-${sc_platform}.${sc_distro_fmt}
  sc_readyfile=sauce-connect-ready-$RANDOM
  sc_logfile=$HOME/sauce-connect.log
  if [ ! -z "${TRAVIS_JOB_NUMBER}" ]; then
    sc_tunnel_id_arg="-i ${TRAVIS_JOB_NUMBER}"
  fi
  echo "Downloading Sauce Connect"
  wget http://saucelabs.com/downloads/${sc_distro}
  sc_actual_shasum="$(openssl sha1 ${sc_distro} | cut -d' ' -f2)"
  if [[ "$sc_actual_shasum" != "$sc_distro_shasum" ]]; then
      echo "SHA1 sum of Sauce Connect file didn't match!"
      return 1
  fi
  sc_dir=$(tar -ztf ${sc_distro} | head -n1)

  echo "Extracting Sauce Connect"
  case "${sc_distro_fmt}" in
      tar.gz)
          tar zxf $sc_distro;;
      zip)
          unzip $sc_distro;;
  esac

  ${sc_dir}/bin/sc \
    ${sc_tunnel_id_arg} \
    -f ${sc_readyfile} \
    -l ${sc_logfile} \
    ${SAUCE_NO_SSL_BUMP_DOMAINS} \
    ${SAUCE_DIRECT_DOMAINS} \
    ${SAUCE_TUNNEL_DOMAINS} &
  _SC_PID="$!"

  echo "Waiting for Sauce Connect readyfile"
  while [ ! -f ${sc_readyfile} ]; do
    sleep .5
  done

  popd
}

function travis_stop_sauce_connect() {
  if [[ ${_SC_PID} = unset ]] ; then
    echo "No running Sauce Connect tunnel found"
    return 1
  fi

  kill ${_SC_PID}

  for i in 0 1 2 3 4 5 6 7 8 9 ; do
    if kill -0 ${_SC_PID} &>/dev/null ; then
      echo "Waiting for graceful Sauce Connect shutdown"
      sleep 1
    else
      echo "Sauce Connect shutdown complete"
      return 0
    fi
  done

  if kill -0 ${_SC_PID} &>/dev/null ; then
    echo "Forcefully terminating Sauce Connect"
    kill -9 ${_SC_PID} &>/dev/null || true
  fi
}
