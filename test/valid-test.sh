#!/bin/sh

cd ${0%/*}
fails=0
i=0
tests=`ls valid/*.argp* | wc -l`
echo "1..${tests##* }"
# Standard valid tests
for argpfile in valid/*.argp*
do
  input="${argpfile%.*}.json"
  expected="${argpfile%.*}_${argpfile##*.}.parsed"
  argp=$(cat $argpfile)
  i=$((i+1))
  if ! ../JSONPath.sh -- "$argp" < "$input" | diff -u - "$expected" 
  then
    echo "not ok $i - $argpfile"
    fails=$((fails+1))
  else
    echo "ok $i - $argpfile"
  fi
done
echo "$fails test(s) failed"
exit $fails
