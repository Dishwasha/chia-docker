#!/usr/bin/env bash

# shellcheck disable=SC2154
if [[ -n "${TZ}" ]]; then
  echo "Setting timezone to ${TZ}"
  ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime && echo "$TZ" > /etc/timezone
fi

cd /home/docker/chia-blockchain || exit 1

# shellcheck disable=SC1091
. ./activate

chia init --fix-ssl-permissions

if [[ ${testnet} == 'true' ]]; then
   echo "configure testnet"
   chia configure --testnet true
else
  chia configure
fi

if [[ ${keys} == "persistent" ]]; then
  echo "Not touching key directories"
elif [[ ${keys} == "generate" ]]; then
  echo "to use your own keys pass them as a text file -v /path/to/keyfile:/path/in/container and -e keys=\"/path/in/container\""
  chia keys generate
elif [[ ${keys} == "copy" ]]; then
  if [[ -z ${ca} ]]; then
    echo "A path to a copy of the farmer peer's ssl/ca required."
	exit
  else
  chia init -c "${ca}"
  fi
else
  chia keys add -f "${keys}"
fi

if [[ ${local} == 'true' ]]; then
   nameserver=`grep nameserver /etc/resolv.conf | cut -d ' ' -f 2`
  if [[ ${testnet} == 'true' ]]; then
    sed -i "s/dns-introducer-testnet10.chia.net/$nameserver/g" "$CHIA_ROOT/config/config.yaml"
    sed -i "s/introducer-testnet10.chia.net/$NODE/g" "$CHIA_ROOT/config/config.yaml"
  else
    sed -i "s/dns-introducer.chia.net/$nameserver/g" "$CHIA_ROOT/config/config.yaml"
    sed -i "s/introducer.chia.net/$NODE/g" "$CHIA_ROOT/config/config.yaml"
  fi
  sed -i "s/127.0.0.1/$NODE/g" "$CHIA_ROOT/config/config.yaml"
  sed -i "s/localhost/$NODE/g" "$CHIA_ROOT/config/config.yaml"
fi

for p in ${plots_dir//:/ }; do
    mkdir -p "${p}"
    if [[ ! $(ls -A "$p") ]]; then
        echo "Plots directory '${p}' appears to be empty, try mounting a plot directory with the docker -v command"
    fi
    chia plots add -d "${p}"
done

chia configure --upnp "${upnp}"

if [[ -n "${log_level}" ]]; then
  chia configure --log-level "${log_level}"
fi

sed -i 's/localhost/127.0.0.1/g' "$CHIA_ROOT/config/config.yaml"

if [[ -n "${GENESIS_CHALLENGE}" ]]; then
  sed -i "s/GENESIS_CHALLENGE: .*/GENESIS_CHALLENGE: $GENESIS_CHALLENGE/g" "$CHIA_ROOT/config/config.yaml"
fi

if [[ -n "${DIFFICULTY_CONSTANT_FACTOR}" ]]; then
  sed -i "s/DIFFICULTY_CONSTANT_FACTOR: .*/DIFFICULTY_CONSTANT_FACTOR: $DIFFICULTY_CONSTANT_FACTOR/g" "$CHIA_ROOT/config/config.yaml"
fi

if [[ ${log_to_file} != 'true' ]]; then
  sed -i 's/log_stdout: false/log_stdout: true/g' "$CHIA_ROOT/config/config.yaml"
else
  sed -i 's/log_stdout: true/log_stdout: false/g' "$CHIA_ROOT/config/config.yaml"
fi

exec "$@"
