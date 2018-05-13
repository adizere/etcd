#!/bin/bash

ETCD_CLIENT_PORT=8081
RETRIES=3

input=$1
if [[ ! -r "${input}" ]]; then
    echo "Input '${input}' not readable: need a file with all the replicas of the ensemble!";
    exit;
fi

for (( i = 0; i < "${RETRIES}"; i++ )); do
    while read -u 31 ip; do

        # echo -e "\t.. Checking replica on ${ip}";

        curl -s -L "http://${ip}:${ETCD_CLIENT_PORT}/v2/stats/leader" 2>&1 | grep -v 'not' >/dev/null
        if [[ $? -eq 0 ]]; then
            echo "${ip}"
            exit 0;
        fi
        # echo "${ip} is not the leader ($?)"

    done 31<${input};
    sleep 1;
done

exit 1;