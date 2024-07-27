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
tests=$(find valid -name '*.argp*' -print | wc -l)
echo "1..${tests##* }"
# Json output tests
find valid -name '*.argp*' -print | while read -r argpfile;
do
  input="${argpfile%.*}.json"
  argp=$(< "$argpfile")
  ((++i))
  if ! ../JSONPath.sh -j -- "$argp" < "$input" | python3 -mjson.tool >/dev/null
  then
    echo "not ok $i - $argpfile"
    ((++fails))
  else
    echo "ok $i - JSON validated for $argpfile"
  fi
done
echo "$fails test(s) failed"
exit "$fails"
