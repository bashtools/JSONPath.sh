#!/usr/bin/env bash

shopt -s lastpipe
export CD_FAILED=
cd "${0%/*}" || CD_FAILED="true"
if [[ -n $CD_FAILED ]]; then
   echo "$0: ERROR: cannot cd ${0%/*}" 1>&2
   exit 1
fi

#set -e
fail=0
tests=0
#all_tests=${__dirname:}
#echo PLAN ${#all_tests}
find test -mindepth 1 -maxdepth 1 -name '*.sh' -print | while read -r test;
do
  ((++tests))
  echo TEST: "$test"
  ./"$test"
  ret=$?
  if [[ $ret -eq 0 ]]; then
    echo OK: ---- "$test"
    ((++passed))
  else
    echo FAIL: "$test" "$fail"
    ((fail=fail+ret))
  fi
done

if [[ $fail -eq 0 ]]; then
  echo -n 'SUCCESS '
  exitcode=0
else
  echo -n 'FAILURE '
  exitcode=1
fi
echo "$passed" "/" "$tests"
exit "$exitcode"
