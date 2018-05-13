

* http://play.etcd.io/install to generate the config files
    - no need for secure connection
    - need to replace ips with 0.0.0.0

* sample:

```
# cat run1:
/home/ubuntu/etcd/etcd --name s1 \
  --data-dir /tmp/s1 \
  --listen-client-urls http://0.0.0.0:8081 \
  --advertise-client-urls http://0.0.0.0:8081 \
  --listen-peer-urls http://0.0.0.0:8082 \
  --initial-advertise-peer-urls http://18.197.134.239:8082 \
  --initial-cluster s1=http://18.197.134.239:8082,s2=http://18.130.88.71:8082,s3=http://34.246.134.122:8082 \
  --initial-cluster-token tkn \
  --initial-cluster-state new
```

* use four machines in total
    - three for replicas
    - if replica code needs modifications, raft/raft.go is the main file
    - all my modifications are tagged with 'counting' (see also the git commits)
    - run replica:

```
rm -rf /tmp/s* ; bash run1 2>&1 | grep --line-buffered counting | tee log1
```

* client:
    - one machine for client
    - client should connect to leader (see discover.sh)
    - client workload has plenty of parameters, but the gist is:

```
python2 workload.py 34.246.134.122 8081 32000 10
```

* log processing:
    - copy the logs (see the scp below)
    - then mount the machine with logs on my laptop
    - and invoke `perl count.pl` to get the results

```
scp -i ~/.ssh/now-key root@18.197.134.239:/home/ubuntu/etcd/log* ./logs/ && scp -i ~/.ssh/now-key root@18.130.88.71:/home/ubuntu/etcd/log* ./logs/ && scp -i ~/.ssh/now-key root@34.246.134.122:/home/ubuntu/etcd/log* ./logs/
```
