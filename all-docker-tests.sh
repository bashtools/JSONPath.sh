#!/usr/bin/env bash

log=testlog.log

# Fedora
export IMAGE=json-path-fedora-bash
cp test/docker/Dockerfile-fedora test/docker/Dockerfile
./test/docker/wrap_in_docker.sh ./all-tests.sh | tee "$log"

a=$(grep 'test(s) failed' "$log")

# Ubuntu
export IMAGE=json-path-ubuntu-bash
cp test/docker/Dockerfile-ubuntu test/docker/Dockerfile
./test/docker/wrap_in_docker.sh ./all-tests.sh | tee "$log"

b=$(grep 'test(s) failed' "$log")

# Centos
export IMAGE=json-path-centos-bash
cp test/docker/Dockerfile-centos test/docker/Dockerfile
./test/docker/wrap_in_docker.sh ./all-tests.sh | tee "$log"

c=$(grep 'test(s) failed' "$log")

# Debian
export IMAGE=json-path-debian-bash
cp test/docker/Dockerfile-debian test/docker/Dockerfile
./test/docker/wrap_in_docker.sh ./all-tests.sh | tee "$log"

d=$(grep 'test(s) failed' "$log")

# Cleanup
rm -- "$log"
rm test/docker/Dockerfile

# Results
echo
echo "Fedora tests"
echo "$a"
echo "Ubuntu tests"
echo "$b"
echo "Centos tests"
echo "$c"
echo "Debian tests"
echo "$d"
