#!/bin/sh

cd ${0%/*}
fails=0
i=0
tests=`ls flatten/*.argp* | wc -l`
echo "1..${tests##* }"
# Standard flatten tests
for argpfile in flatten/*.argp*
do
  input="${argpfile%.*}.json"
  expected="${argpfile%.*}_${argpfile##*.}.flattened"
  argp=$(cat $argpfile)
  i=$((i+1))
  if ! ../JSONPath.sh "$argp" -u < "$input" | diff -u - "$expected" 
  then
    echo "not ok $i - $argpfile"
    fails=$((fails+1))
  else
    echo "ok $i - $argpfile"
  fi
done
echo "$fails test(s) failed"
exit $fails
