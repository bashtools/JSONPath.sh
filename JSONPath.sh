#!/usr/bin/env bash

# ---------------------------------------------------------------------------
# GLOBALS
# ---------------------------------------------------------------------------

VERSION="0.0.21"
DEBUG=0
NOCASE=0
WHOLEWORD=0
FILE=
NO_HEAD=0
NORMALIZE_SOLIDUS=0
BRIEF=0
PASSTHROUGH=0
JSON=0
MULTIPASS=0
FLATTEN=0
COLON_SPACE=0
CONDENSED=0
TAB_INDENT=0
STDINFILE=/var/tmp/JSONPath.$$.stdin
STDINFILE2=/var/tmp/JSONPath.$$.stdin2
PASSFILE=/var/tmp/JSONPath.$$.pass1
declare -a INDEXMATCH_QUERY

# ---------------------------------------------------------------------------
main() {
# ---------------------------------------------------------------------------
# It all starts here

  sanity_checks
  parse_options "$@"

  trap cleanup EXIT

  if [[ $QUERY == *'?(@'* ]]; then
    # This will be a multipass query

    [[ -n $FILE ]] && STDINFILE="$FILE"
    [[ -z $FILE ]] && cat >"$STDINFILE"

    while true; do
      tokenize_path
      create_filter

      tokenize < "$STDINFILE" | parse | filter | indexmatcher >"$PASSFILE"

      [[ $MULTIPASS -eq 1 ]] && {
        # replace filter expression with index sequence
        SET=$(sed -rn 's/.*[[,"]+([0-9]+)[],].*/\1/p' "$PASSFILE" | tr '\n' ,)
        SET=${SET%,}
        # shellcheck disable=2001
        QUERY=$(echo "$QUERY" | sed "s/?(@[^)]\+)/$SET/")
        [[ $DEBUG -eq 1 ]] && echo "QUERY=$QUERY" >/dev/stderr
        reset
        continue
      }

      flatten < "$PASSFILE" | json | brief

      break
    done

  else

    tokenize_path
    create_filter

    if [[ $PASSTHROUGH -eq 1 ]]; then
      JSON=1
      flatten | json
    elif [[ -z $FILE ]]; then
      tokenize | parse | filter | indexmatcher | flatten | json | brief
    else
      tokenize < "$FILE" | parse | filter | indexmatcher | flatten | \
        json | brief
    fi

  fi
}

# ---------------------------------------------------------------------------
sanity_checks() {
# ---------------------------------------------------------------------------

  # Reset some vars
  for binary in gawk grep sed; do
    if ! command -v "$binary" >& /dev/null; then
      echo "ERROR: $binary binary not found in path. Aborting."
      exit 1
    fi
  done
}

# ---------------------------------------------------------------------------
reset() {
# ---------------------------------------------------------------------------

  # Reset some vars
  declare -a INDEXMATCH_QUERY
  PATHTOKENS=
  FILTER=
  OPERATOR=
  RHS=
  MULTIPASS=0
}

# ---------------------------------------------------------------------------
cleanup() {
# ---------------------------------------------------------------------------

  [[ -e "$PASSFILE" ]] && rm -f "$PASSFILE"
  [[ -e "$STDINFILE2" ]] && rm -f "$STDINFILE2"
  [[ -z "$FILE" && -e "$STDINFILE" ]] && rm -f "$STDINFILE"
}

# ---------------------------------------------------------------------------
usage() {
# ---------------------------------------------------------------------------

  echo
  echo "Usage: JSONPath.sh [-[vhbjuipwnsSAT]] [-f FILE] [pattern]"
  echo
  echo "-v      - Print the version of this script."
  echo "-h      - Print this help text."
  echo "-b      - Brief. Only show values."
  echo "-i      - Case insensitive."
  echo "-p      - Pass-through to the JSON parser."
  echo "-w      - Match whole words only (for filter script expression)."
  echo "-f FILE - Read a FILE instead of stdin."
  echo "-n      - Do not print header."
  echo "-T      - Indent with tabs instead of 4 character spaces."
  echo "-u      - Strip unnecessary leading path elements."
  echo "-j      - Output in JSON format."
  echo "-s      - JSON output: Normalize solidus, e.g. convert \"\/\" to \"/\"."
  echo "-S      - JSON output: Print spaces around colons, producing ' : '."
  echo "-c      - JSON output: Condensed output."
  echo "pattern - the JSONPath query. Defaults to '$.*' if not supplied."
  echo
}

# ---------------------------------------------------------------------------
parse_options() {
# ---------------------------------------------------------------------------

  set -- "$@"

  local arg ARGN=$#
  declare -a expanded_args

  # Expand args like -abc to -a -b -c
  while [ "$ARGN" -ne 0 ]; do
    arg="$1"
    if [[ $arg == -[a-zA-Z][a-zA-Z]* ]]; then
        # Remove the leading dash
        arg="${arg#-}"
        # Split the remaining characters and add dashes
        for i in ${arg//[a-zA-Z]/ -&}; do
            expanded_args+=("$i")
        done
    else
        expanded_args+=("$arg")
    fi
    ARGN=$((ARGN-1))
    shift 1
  done

  set -- "${expanded_args[@]}"
  ARGN=$#
  while [ "$ARGN" -ne 0 ]
  do
    case $1 in
      -h) usage
          exit 0
      ;;
      -v) echo "Version: $VERSION"
          exit 0
      ;;
      -f) shift
          [[ ! -e $1 ]] && {
            echo "ERROR: -f '$1' does not exist." 1>&2
            exit 1
          }
          FILE=$1
      ;;
      -c) CONDENSED=1
      ;;
      -i) NOCASE=1
      ;;
      -j) JSON=1
      ;;
      -n) NO_HEAD=1
      ;;
      -b) BRIEF=1
      ;;
      -u) FLATTEN=1
      ;;
      -p) PASSTHROUGH=1
      ;;
      -w) WHOLEWORD=1
      ;;
      -s) NORMALIZE_SOLIDUS=1
      ;;
      -S) COLON_SPACE=1
         ;;
      -T) TAB_INDENT=1
         ;;
      -?*) usage
           echo "$0: ERROR: invalid option: $1" 1>&2
           exit 3
      ;;
      ?*) QUERY=$1
      ;;
    esac
    shift 1
    ARGN=$((ARGN-1))
  done

  [[ -z $QUERY ]] && QUERY='.*'
}

# ---------------------------------------------------------------------------
awk_egrep() {
# ---------------------------------------------------------------------------
  local pattern_string="$1"

  gawk '{
    while ($0) {
      start=match($0, pattern);
      token=substr($0, start, RLENGTH);
      print token;
      $0=substr($0, start+RLENGTH);
    }
  }' pattern="$pattern_string"
}

# ---------------------------------------------------------------------------
tokenize() {
# ---------------------------------------------------------------------------
# json parsing

  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | grep -E -ao --color=never "test" >/dev/null 2>&1
  then
    GREP='grep -E -ao --color=never'
  else
    GREP='grep -E -ao'
  fi

  if echo "test string" | grep -E -o "test" >/dev/null 2>&1
  then
    ESCAPE='(\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=awk_egrep
    ESCAPE='(\\\\[^u[:cntrl:]]|\\u[0-9a-fA-F]{4})'
    CHAR='[^[:cntrl:]"\\\\]'
  fi

  local STRING="\"$CHAR*($ESCAPE$CHAR*)*\""
  local NUMBER='-?(0|[1-9][0-9]*)([.][0-9]*)?([eE][+-]?[0-9]*)?'
  local KEYWORD='null|false|true'
  local SPACE='[[:space:]]+'

  # Force zsh to expand $A into multiple words
  local is_wordsplit_disabled
  is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
  if [[ $is_wordsplit_disabled != 0 ]]; then setopt shwordsplit; fi
  $GREP "$STRING|$NUMBER|$KEYWORD|$SPACE|." | grep -E -v "^$SPACE$"
  if [[ $is_wordsplit_disabled != 0 ]]; then unsetopt shwordsplit; fi
}

# ---------------------------------------------------------------------------
tokenize_path () {
# ---------------------------------------------------------------------------
  local GREP
  local ESCAPE
  local CHAR

  if echo "test string" | grep -E -ao --color=never "test" >/dev/null 2>&1
  then
    GREP='grep -E -ao --color=never'
  else
    GREP='grep -E -ao'
  fi

  if echo "test string" | grep -E -o "test" >/dev/null 2>&1
  then
    CHAR='[^[:cntrl:]"\\]'
  else
    GREP=awk_egrep
  fi

  local WILDCARD='\*'
  local WORD='[ A-Za-z0-9_-]*'
  local INDEX="\\[$WORD(:$WORD){0,2}\\]"
  local INDEXALL="\\[\\*\\]"
  local STRING="[\\\"'][^[:cntrl:]\\\"']*[\\\"']"
  local SET="\\[($WORD|$STRING)(,($WORD|$STRING))*\\]"
  local FILTER='\?\(@[^)]+'
  local DEEPSCAN="\\.\\."
  local SPACE='[[:space:]]+'

  # Force zsh to expand $A into multiple words
  local is_wordsplit_disabled
  is_wordsplit_disabled=$(unsetopt 2>/dev/null | grep -c '^shwordsplit$')
  if [[ $is_wordsplit_disabled != 0 ]]; then setopt shwordsplit; fi
  readarray -t PATHTOKENS < <( echo "$QUERY" | \
    $GREP "$INDEX|$STRING|$WORD|$WILDCARD|$FILTER|$DEEPSCAN|$SET|$INDEXALL|." | \
    grep -E -v "^$SPACE$|^\\.$|^\[$|^\]$|^'$|^\\\$$|^\)$")
  [[ $DEBUG -eq 1 ]] && {
    echo "grep -E -o '$INDEX|$STRING|$WORD|$WILDCARD|$FILTER|$DEEPSCAN|$SET|$INDEXALL|.'" >/dev/stderr
    echo -n "TOKENISED QUERY="; echo "$QUERY" | \
      $GREP "$INDEX|$STRING|$WORD|$WILDCARD|$FILTER|$DEEPSCAN|$SET|$INDEXALL|." | \
      grep -E -v "^$SPACE$|^\\.$|^\[$|^\]$|^'$|^\\\$$|^\)$" >/dev/stderr
  }
  if [[ $is_wordsplit_disabled != 0 ]]; then unsetopt shwordsplit; fi
}

# ---------------------------------------------------------------------------
create_filter() {
# ---------------------------------------------------------------------------
# Creates the filter from the user's query.
# Filter works in a single pass through the data, unless a filter (script)
#  expression is used, in which case two passes are required (MULTIPASS=1).

  local len=${#PATHTOKENS[*]}

  local -i i=0
  local query="^\[" comma=
  while [[ i -lt len ]]; do
    case "${PATHTOKENS[i]}" in
      '"') :
      ;;
      '..') query+="${comma}[^]]*"
            comma=
      ;;
      '[*]') query+="${comma}[^,]*"
             comma=","
      ;;
      '*') query+="${comma}(\"[^\"]*\"|[0-9]+[^],]*)"
           comma=","
      ;;
      '?(@'*) a=${PATHTOKENS[i]#?(@.}
               elem="${a%%[<>=!]*}"
               rhs="${a##*[<>=!]}"
               a="${a#"$elem"}"
               elem="${elem//./[\",.]+}" # Allows child node matching
               operator="${a%"${rhs}"}"
               [[ -z $operator ]] && { operator="=="; rhs=; }
               if [[ $rhs == *'"'* || $rhs == *"'"* ]]; then
                 case "$operator" in
                   '=='|'=')  OPERATOR=
                          if [[ $elem == '?(@' ]]; then
                            # To allow search on @.property such as:
                            #   $..book[?(@.title==".*Book 1.*")]
                            query+="${comma}[0-9]+[],][[:space:]\"]*${rhs//\"/}"
                          else
                            # To allow search on @ (this node) such as:
                            #   $..reviews[?(@==".*Fant.*")]
                            query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*${rhs//\"/}"
                          fi
                          FILTER="$query"
                     ;;
                   '>='|'>')  OPERATOR=">"
                              RHS="$rhs"
                              query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                              FILTER="$query"
                     ;;
                   '<='|'<')  OPERATOR="<"
                              RHS="$rhs"
                              query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                              FILTER="$query"
                     ;;
                  *)
                     ;;
                 esac
               else
                 case $operator in
                   '=='|'=')  OPERATOR=
                          query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*$rhs"
                          FILTER="$query"
                     ;;
                   '>=')  OPERATOR="-ge"
                          RHS="$rhs"
                          query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                          FILTER="$query"
                     ;;
                   '>')   OPERATOR="-gt"
                          RHS="$rhs"
                          query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                          FILTER="$query"
                     ;;
                   '<=')  OPERATOR="-le"
                          RHS="$rhs"
                          query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                          FILTER="$query"
                     ;;
                   '<')   OPERATOR="-lt"
                          RHS="$rhs"
                          query+="${comma}[0-9]+,\"$elem\"[],][[:space:]\"]*"
                          FILTER="$query"
                    ;;
                  *)
                     ;;
                 esac
               fi
               MULTIPASS=1
      ;;
      "["*) if [[ ${PATHTOKENS[i]} =~ , ]]; then
              a=${PATHTOKENS[i]#[}
              a=${a%]}
              if [[ $a =~ [[:alpha:]] ]]; then
                # converts only one comma: s/("[^"]+),([^"]+")/\1`\2/g;s/"//g
                #a=$(echo $a | sed 's/\([[:alpha:]]*\)/"\1"/g')
                a=$(echo "$a" | sed -r "s/[\"']//g;s/([^,]*)/\"\1\"/g")
              fi
              query+="${comma}(${a//,/|})"
            elif [[ ${PATHTOKENS[i]} =~ : ]]; then
              if ! [[ ${PATHTOKENS[i]} =~ [0-9][0-9] || ${PATHTOKENS[i]} =~ :] ]]
              then
                if [[ ${PATHTOKENS[i]#*:} =~ : ]]; then
                  INDEXMATCH_QUERY+=("${PATHTOKENS[i]}")
                  query+="${comma}[^,]*"
                else
                  # Index in the range of 0-9 can be handled by regex
                  query+="${comma}$(echo "${PATHTOKENS[i]}" |
                  gawk '/:/ { a=substr($0,0,index($0,":")-1);
                         b=substr($0,index($0,":")+1,index($0,"]")-index($0,":")-1);
                         if(b>0) { print a ":" b-1 "]" };
                         if(b<=0) { print a ":]" } }' | \
                  sed 's/\([0-9]\):\([0-9]\)/\1-\2/;
                       s/\[:\([0-9]\)/[0-\1/;
                       s/\([0-9]\):\]/\1-9999999]/')"
                fi
              else
                INDEXMATCH_QUERY+=("${PATHTOKENS[i]}")
                query+="${comma}[^,]*"
              fi
            else
              a=${PATHTOKENS[i]#[}
              a=${a%]}
              if [[ $a =~ [[:alpha:]] ]]; then
                a=$(echo "$a" | sed -r "s/[\"']//g;s/([^,]*)/\"\1\"/g")
              else
                [[ $i -gt 0 ]] && comma=","
              fi
              query+="$comma$a"
            fi
            comma=","
      ;;
      *)    PATHTOKENS[i]=${PATHTOKENS[i]//\'/\"}
            query+="$comma\"${PATHTOKENS[i]//\"/}\""
            comma=","
      ;;
    esac
    ((++i))
  done

  [[ -z $FILTER ]] && FILTER="${query}[],]"
  [[ $DEBUG -eq 1 ]] && echo "FILTER=$FILTER" >/dev/stderr
}

# ---------------------------------------------------------------------------
parse_array () {
# ---------------------------------------------------------------------------
# json parsing

  local index=0
  local ary=''
  read -r token
  case "$token" in
    ']')
         ;;
    *)
      while :
      do
        parse_value "$1" "$index"
        index=$((index+1))
        ary="$ary""$value"
        read -r token
        case "$token" in
          ']') break ;;
          ',') ary="$ary," ;;
          *) throw "EXPECTED , or ] GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
      ;;
  esac
  value=
  :
}

# ---------------------------------------------------------------------------
parse_object () {
# ---------------------------------------------------------------------------
# json parsing

  local key
  local obj=''
  read -r token
  case "$token" in
    '}')
         ;;
    *)
      while :
      do
        case "$token" in
          '"'*'"') key="$token" ;;
          *) throw "EXPECTED string GOT ${token:-EOF}" ;;
        esac
        read -r token
        case "$token" in
          ':') ;;
          *) throw "EXPECTED : GOT ${token:-EOF}" ;;
        esac
        read -r token
        parse_value "$1" "$key"
        obj="$obj$key:$value"
        read -r token
        case "$token" in
          '}') break ;;
          ',') obj="$obj," ;;
          *) throw "EXPECTED , or } GOT ${token:-EOF}" ;;
        esac
        read -r token
      done
    ;;
  esac
  value=
  :
}

# ---------------------------------------------------------------------------
parse_value () {
# ---------------------------------------------------------------------------
# json parsing

  local jpath="${1:+$1,}$2" isleaf=0 isempty=0 print=0
  case "$token" in
    '{') parse_object "$jpath" ;;
    '[') parse_array  "$jpath" ;;
    # At this point, the only valid single-character tokens are digits.
    ''|[!0-9]) throw "EXPECTED value GOT ${token:-EOF}" ;;
    *) value="$token"
       # if asked, replace solidus ("\/") in json strings with normalized value: "/"
       # shellcheck disable=SC2001
       [[ "$NORMALIZE_SOLIDUS" -eq 1 ]] && value=$(echo "$value" | sed 's#\\/#/#g')
       isleaf=1
       [[ "$value" = '""' ]] && isempty=1
       ;;
  esac
  [[ "$value" = '' ]] && return
  [[ "$NO_HEAD" -eq 1 && -z "$jpath" ]] && return

  [[ "$isleaf" -eq 1 && $isempty -eq 0 ]] && print=1
  [[ "$print" -eq 1 ]] && printf "[%s]\t%s\n" "$jpath" "$value"
  :
}

# ---------------------------------------------------------------------------
flatten() {
# ---------------------------------------------------------------------------
# Take out

  local path a prevpath pathlen

  if [[ $FLATTEN -eq 1 ]]; then
    cat >"$STDINFILE2"

    highest=9999

    while read -r line; do
      a=${line#[}; a=${a%%]*}
      readarray -t path < <(grep -o "[^,]*"<<<"$a")
      [[ -z $prevpath ]] && {
        prevpath=("${path[@]}")
        highest=$((${#path[*]}-1))
        continue
      }

      pathlen=$((${#path[*]}-1))

      for i in $(seq 0 "$pathlen"); do
        [[ ${path[i]} != "${prevpath[i]}" ]] && {
          high="$i"
          break
        }
      done

      [[ $high -lt $highest ]] && highest="$high"

      prevpath=("${path[@]}")
    done <"$STDINFILE2"

    if [[ $highest -gt 0 ]]; then
      sed -r 's/\[(([0-9]+|"[^"]+")[],]){'$((highest))'}(.*)/[\3/' \
        "$STDINFILE2"
    else
      cat "$STDINFILE2"
    fi
  else
    cat
  fi
}

# ---------------------------------------------------------------------------
indexmatcher() {
# ---------------------------------------------------------------------------
# For double digit or greater indexes match each line individually
# Single digit indexes are handled more efficiently by regex

  local a b

  [[ $DEBUG -eq 1 ]] && {
    for i in $(seq 0 $((${#INDEXMATCH_QUERY[*]}-1))); do
      echo "INDEXMATCH_QUERY[$i]=${INDEXMATCH_QUERY[i]}" >/dev/stderr
    done
  }

  matched=1

  step=
  if [[ ${#INDEXMATCH_QUERY[*]} -gt 0 ]]; then
    while read -r line; do
      for i in $(seq 0 $((${#INDEXMATCH_QUERY[*]}-1))); do
        [[ ${INDEXMATCH_QUERY[i]#*:} =~ : ]] && {
          step=${INDEXMATCH_QUERY[i]##*:}
          step=${step%]}
          INDEXMATCH_QUERY[i]="${INDEXMATCH_QUERY[i]%:*}]"
        }
        q=${INDEXMATCH_QUERY[i]:1:-1} # <- strip '[' and ']'
        a=${q%:*}                     # <- number before ':'
        b=${q#*:}                     # <- number after ':'
        [[ -z $b ]] && b=99999999999
        readarray -t num < <( (grep -Eo '[0-9]+[],]' | tr -d ,])<<<"$line" )
        if [[ ${num[i]} -ge $a && ${num[i]} -lt $b && matched -eq 1 ]]; then
          matched=1
          [[ $i -eq $((${#INDEXMATCH_QUERY[*]}-1)) ]] && {
            if [[ $step -gt 1 ]]; then
              [[ $(((num[i]-a)%step)) -eq 0 ]] && {
                [[ $DEBUG -eq 1 ]] && echo -n "($a,$b,${num[i]}) " >/dev/stderr
                echo "$line"
              }
            else
              [[ $DEBUG -eq 1 ]] && echo -n "($a,$b,${num[i]}) " >/dev/stderr
              echo "$line"
            fi
          }
        else
          matched=0
          continue
        fi
      done
      matched=1
    done
  else
    cat -
  fi
}

# ---------------------------------------------------------------------------
brief() {
# ---------------------------------------------------------------------------
# Only show the value

    if [[ $BRIEF -eq 1 ]]; then
      sed 's/^[^\t]*\t//;s/^"//;s/"$//;'
    else
      if [[ $TAB_INDENT == 1 ]]; then
        # TODO should not be using another external tool
        # Only gawk, grep and sed are allowed
        unexpand -t 4
      else
        cat
      fi
    fi
}

# ---------------------------------------------------------------------------
typeof() {
# ---------------------------------------------------------------------------
# Helper function for json()

  [[ -z $1 ]] && return 1
  if [[ $1 == \"* ]]; then
    echo OBJECT
  else
    echo ARRAY
  fi
  return 0
}

# ---------------------------------------------------------------------------
get_path_stats() {
# ---------------------------------------------------------------------------
# Compare the current path to the previous path
# Helper function for json()

  num_same=0; rest_is_new=
  num_new=0; num_dropped=0; num_changed=0
  new_objs=(); dropped_objs=(); changed_objs=()

  for i in $(seq 0 $((${#curpath[*]}-1))); do
    if [[ -n "${rest_is_new}" ]]; then
      num_new+=1
      new_objs+=("$(typeof "${curpath[i]}")")
      num_dropped+=1
      dropped_objs+=("$(typeof "${prvpath[i]}")")
    elif ! typeof "${prvpath[i]}" >/dev/null; then
      num_new+=1
      new_objs+=("$(typeof "${curpath[i]}")")
      rest_is_new=1
      num_dropped+=1
      dropped_objs+=("$(typeof "${prvpath[i]}")")
    elif [[ "${curpath[i]}" != "${prvpath[i]}" ]]; then
      if [[ $(typeof "${curpath[i]}") == "OBJECT" ]]; then
        num_changed+=1
        changed_objs+=("$(typeof "${curpath[i]}")")
      else
        num_same+=1
      fi
      rest_is_new=1
    elif [[ "${num_new}" -eq 0 && "${num_changed}" -eq 0 ]]; then
      num_same+=1
    fi
  done
  if [[ ${#prvpath[*]} -gt ${#curpath[*]} ]]; then
    num_dropped=$((${#prvpath[*]}-${#curpath[*]}))
    for i in $(seq $((${#prvpath[*]}-num_dropped)) $((${#prvpath[*]}-1)))
    do
      dropped_objs+=("$(typeof "${prvpath[i]}")")
    done
  fi
}

# ---------------------------------------------------------------------------
json() {
# ---------------------------------------------------------------------------
# Turn output into JSON

  local rawpath tab comma nl spc first_time=1
  # using declare makes these variables available to called functions
  declare -a curpath prvpath new_objs dropped_objs changed_objs
  declare -i num_same=0 num_new=0 num_dropped=0
  declare -i num_changed=0 indent=0 tabsize=0 tsc=0

  tab=$(echo -e "\t")

  [[ $CONDENSED -eq 0 ]] && { nl='\n'; spc=' '; tabsize=2; tsc=2; }
  [[ $COLON_SPACE -eq 1 ]] && cs=" "

  if [[ $JSON -eq 0 ]]; then
    cat -
  else
    while read -r line; do
      rawpath=${line#[}; rawpath=${rawpath%%]*}
      readarray -t curpath < <(grep -o "[^,]*"<<<"$rawpath")
      value=${line#*"$tab"}

      get_path_stats

      if [[ ${num_dropped} -gt 0 && first_time -eq 0 ]]; then
        for i in $(seq $((${#dropped_objs[*]}-1)) -1 0); do
          case "${dropped_objs[i]}" in
            ARRAY)
              indent=$((indent-1))
              printf "%b%*s]" "$nl" "$((indent*tabsize))" ""
              ;;
            OBJECT)
              indent=$((indent-1))
              printf "%b%*s}" "$nl" "$((indent*tabsize))" ""
              ;;
          esac
        done
        if [[ -n ${comma} ]]; then
          printf "%s%b" "${comma}" "$nl"
          comma=
        else
          printf "%b" "$nl"
        fi
      fi

      if [[ ${num_changed} -gt 0 ]]; then
        [[ -n ${comma} ]] && { printf "%s%b" "${comma}" "$nl"; comma=; }
        for i in $(seq 0 $((${#changed_objs[*]}-1))); do
          case "${changed_objs[i]}" in
            OBJECT)
              printf "%*s%s%s:%s" "$((indent*tabsize))" "" "${curpath[num_same+i]}" "$cs" "$spc"
              ;;
          esac
        done
      fi

      if [[ num_new -gt 0 ]]; then
        [[ -n ${comma} ]] && { printf "%s%b" "${comma}" "$nl"; comma=; }
        for i in $(seq 0 $((${#new_objs[*]}-1))); do
          case "${new_objs[i]}" in
            ARRAY)
              printf "[%b" "$nl"
              indent=$((indent+1))
              ;;
            OBJECT)
              [[ $((num_same+num_changed+i)) -gt 0 && $CONDENSED -eq 0 ]] && {
                if [[ $(typeof "${curpath[num_same+num_changed+i-1]}") == 'ARRAY' ]]; then
                  [[ ${curpath[num_same+num_changed+i-1]} != "${prvpath[num_same+num_changed+i-1]}" ]] &&
                    tsc=2
                fi
              }
              printf "%*s{%b%*s%s%s:%s" \
                "$((indent*tsc))" "" \
                "$nl" \
                "$(((indent+1)*tabsize))" "" \
                "${curpath[num_same+num_changed+i]}" \
                "$cs" "$spc"
              indent=$((indent+1))
              tsc=0
              ;;
          esac
        done
      fi
      
      [[ ${num_dropped} -eq 0 && ${num_changed} -eq 0
         && ${num_new} -eq 0 && -n ${comma} ]] &&
        printf "%s%b" "${comma}" "$nl"; comma=;

      if [[ $(typeof "${curpath[-1]}") == "ARRAY"  && $CONDENSED -eq 0 ]]; then
        printf "%*s%s" "$((indent*tabsize))" "" "$value"
      else
        printf "%s" "$value"
      fi
      comma=","
      first_time=0
      prvpath=("${curpath[@]}")
    done

    curpath=()
    if [[ ${#prvpath[*]} -gt ${#curpath[*]} ]]; then
      printf "%b" "$nl"
      for i in $(seq $((${#prvpath[*]}-1)) -1 0)
      do
        case $(typeof "${prvpath[i]}") in
          ARRAY)
            printf "%*s]%b" "$((i*tabsize))" "" "$nl"
            ;;
          OBJECT)
            printf "%*s}%b" "$((i*tabsize))" "" "$nl"
            ;;
        esac
      done
    fi
    [[ ${CONDENSED} -eq 1 ]] && echo
  fi
}

# ---------------------------------------------------------------------------
filter() {
# ---------------------------------------------------------------------------
# Apply the query filter

  local a tab v
  tab=$(echo -e "\t")
  unset opts
  declare -ag opts

  [[ $NOCASE -eq 1 ]] && opts+=("-i")
  [[ $WHOLEWORD -eq 1 ]] && opts+=("-w")
  if [[ -z $OPERATOR ]]; then
    [[ $MULTIPASS -eq 1 ]] && FILTER="${FILTER}[\"]?$"
    grep -E "${opts[@]}" "$FILTER"
    [[ $DEBUG -eq 1 ]] && echo "FILTER=$FILTER" >/dev/stderr
  else
    grep -E "${opts[@]}" "$FILTER" | \
      while read -r line; do
        v=${line#*"$tab"}
        case "$OPERATOR" in
          '-ge') if gawk '{exit !($1>=$2)}'<<<"$v $RHS";then echo "$line"; fi
            ;;
          '-gt') if gawk '{exit !($1>$2) }'<<<"$v $RHS";then echo "$line"; fi
            ;;
          '-le') if gawk '{exit !($1<=$2) }'<<<"$v $RHS";then echo "$line"; fi
            ;;
          '-lt') if gawk '{exit !($1<$2) }'<<<"$v $RHS";then echo "$line"; fi
            ;;
          '>') v=${v#\"}; v=${v%\"}
               RHS=${RHS#\"}; RHS=${RHS%\"}
               [[ "${v,,}" > "${RHS,,}" ]] && echo "$line"
            ;;
          '<') v=${v#\"}; v=${v%\"}
               RHS=${RHS#\"}; RHS=${RHS%\"}
               [[ "${v,,}" < "${RHS,,}" ]] && echo "$line"
            ;;
          *)
            ;;
        esac
      done
  fi
}

# ---------------------------------------------------------------------------
parse () {
# ---------------------------------------------------------------------------
# Parses json

  read -r token
  parse_value
  read -r token
  if [[ -n $token ]]; then
    throw "EXPECTED EOF GOT $token"
  fi
}

# ---------------------------------------------------------------------------
throw() {
# ---------------------------------------------------------------------------
  echo "$*" >&2
  exit 1
}

if [[ "$0" = "${BASH_SOURCE[*]}" || -z "${BASH_SOURCE[*]}" ]];
then
  main "$@"
fi

# vi: expandtab sw=2 ts=2
