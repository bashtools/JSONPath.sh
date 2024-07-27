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
declare -i tests
tests=$(find valid -name '*.parsed' -print | wc -l)
tests+=$(find flatten -name '*.flattened' -print | wc -l)
echo "1..${tests##* }"
# Json output tests
find valid -name '*.parsed' -print | while read -r file;
do
  ((++i))
  if ! ../JSONPath.sh -p < "$file" | python3 -mjson.tool >/dev/null
  then
    echo "not ok $i - $file"
    ((++fails))
  else
    echo "ok $i - JSON validated for $file"
  fi
done
find flatten -name '*.flattened' -print | while read -r file;
do
  ((++i))
  if ! ../JSONPath.sh -p < "$file" | python3 -mjson.tool >/dev/null
  then
    echo "not ok $i - $file"
    ((++fails))
  else
    echo "ok $i - JSON validated for $file"
  fi
done
echo "$fails test(s) failed"
exit "$fails"
