#!/bin/sh

cd ${0%/*}
fails=0
i=0
tests=`ls valid/*.argp* | wc -l`
echo "1..${tests##* }"
# Json output tests
for argpfile in valid/*.argp*
do
  input="${argpfile%.*}.json"
  argp=$(cat $argpfile)
  i=$((i+1))
  if ! ../JSONPath.sh "$argp" -j < "$input" | python -mjson.tool >/dev/null
  then
    echo "not ok $i - $argpfile"
    fails=$((fails+1))
  else
    echo "ok $i - JSON validated for $argpfile"
  fi
done
echo "$fails test(s) failed"
exit $fails
