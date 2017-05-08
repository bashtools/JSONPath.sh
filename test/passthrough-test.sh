#!/bin/bash

cd ${0%/*}
fails=0
i=0
declare -i tests
tests=`ls valid/*.parsed | wc -l`
tests+=`ls flatten/*.flattened | wc -l`
echo "1..${tests##* }"
# Json output tests
for file in valid/*.parsed
do
  i=$((i+1))
  if ! ../JSONPath.sh -p < "$file" | python -mjson.tool >/dev/null
  then
    echo "not ok $i - $file"
    fails=$((fails+1))
  else
    echo "ok $i - JSON validated for $file"
  fi
done
for file in flatten/*.flattened
do
  i=$((i+1))
  if ! ../JSONPath.sh -p < "$file" | python -mjson.tool >/dev/null
  then
    echo "not ok $i - $file"
    fails=$((fails+1))
  else
    echo "ok $i - JSON validated for $file"
  fi
done
echo "$fails test(s) failed"
exit $fails
