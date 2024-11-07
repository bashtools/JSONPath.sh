#!/usr/bin/env bash

shopt -s lastpipe
CD_FAILED=
cd "${0%/*}" || CD_FAILED="true"
if [[ -n $CD_FAILED ]]; then
   echo "$0: ERROR: cannot cd ${0%/*}" 1>&2
   exit 1
fi
fails=0
i=0
tests=$(find flatten -name '*.argp*' -print | wc -l)
echo "1..${tests##* }"
# Standard flatten tests
find flatten -name '*.argp*' -print | while read -r argpfile;
do
  input="${argpfile%.*}.json"
  expected="${argpfile%.*}_${argpfile##*.}.flattened"
  argp=$(< "$argpfile")
  ((++i))
  if ! ../JSONPath.sh -u "$argp" < "$input" | diff -u -- - "$expected"
  then
    echo "not ok $i - $argpfile"
    ((++fails))
  else
    echo "ok $i - $argpfile"
  fi
done
echo "$fails test(s) failed"
exit "$fails"
