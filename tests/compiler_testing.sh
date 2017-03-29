
LLI="lli"
LLC="llc"
GPP="g++"
JSTEM="../JSTEM.native"
SL="../stdlib.JSTEM"

ulimit -t 30

globallog=testall.log
rm -f $globallog
error=0
globalerror=0

keep=0

filecount=0
failurecount=0

Usage() {
    echo "Usage: testall.sh [options] [.JSTEM files]"
    echo "-k    Keep intermediate files"
    echo "-h    Print this help"
    exit 1
}

SignalError() {
    if [ $error -eq 0 ] ; then
	error=1
    fi
    echo "  $1"
}

# Compare <outfile> <reffile> <difffile>
# Compares the outfile with reffile.  Differences, if any, written to difffile
Compare() {
    generatedfiles="$generatedfiles $3"
    echo diff -b $1 $2 ">" $3 1>&2
    diff -b "$1" "$2" > "$3" 2>&1 || {
	SignalError "$1 differs"
	echo "FAILED $1 differs from $2" 1>&2
    }
}

# Run <args>
# Report the command, run it, and report any errors
Run() {
    echo $* 1>&2
    eval $* || {
	SignalError " -- failed on command $*"
	return 1
    }
}

# RunFail <args>
# Report the command, run it, and expect an error
RunFail() {
    echo $* 1>&2
    eval $* && {
	SignalError "failed: $* did not report an error"
	return 1
    }
    return 0
}

Check() {
    error=0
    basename=`echo $1 | sed 's/.*\\///
                             s/.JSTEM//'`
    reffile=`echo $1 | sed 's/.JSTEM$//'`
    basedir="`echo $1 | sed 's/\/[^\/]*$//'`/."

    echo 1>&2
    echo "###### Testing $basename" 1>&2
    echo -n " - $basename..."

    generatedfiles=""

    generatedfiles="$generatedfiles ${basename}.ll ${basename}.s ${basename}.o a.out ${basename}.out" &&
    Run "$JSTEM -c"  $1 "$SL >" "${basename}.ll" &&
    Run "$LLC" "-filetype=obj" "${basename}.ll" ">" "${basename}.o" &&
    Run "$GPP" "${basename}.o" ">" "a.out" &&
    Run "./a.out" ">" "${basename}.out" &&
    Compare ${basename}.out ${reffile}.out ${basename}.diff

    # Report the status and clean up the generated files

    if [ $error -eq 0 ] ; then
    	if [ $keep -eq 0 ] ; then
    	    rm -f $generatedfiles
    	fi
    	
        filecount=$(expr $filecount + 1)
        printf "...SUCCESS\n" 
    	echo "###### SUCCESS" 1>&2

    else
    	echo "###### FAILURE" 1>&2
    	globalerror=$error
        filecount=$(expr $filecount + 1)
        failurecount=$(expr $failurecount + 1)
    fi
}

CheckFail() {
    error=0
    basename=`echo $1 | sed 's/.*\\///
                             s/.JSTEM//'`
    reffile=`echo $1 | sed 's/.JSTEM$//'`
    basedir="`echo $1 | sed 's/\/[^\/]*$//'`/."

    echo -n " - $basename..."

    echo 1>&2
    echo "###### Testing $basename" 1>&2

    generatedfiles=""

    generatedfiles="$generatedfiles ${basename}.err ${basename}.diff" &&
    RunFail "$ML" $1 "2>" "${basename}.err" ">>" $globallog &&
    Compare ${basename}.err ${reffile}.err ${basename}.diff

    # Report the status and clean up the generated files

    if [ $error -eq 0 ] ; then
	if [ $keep -eq 0 ] ; then
	    rm -f $generatedfiles
	fi
	echo "SUCCESS"
	echo "###### SUCCESS" 1>&2
    filecount=$(expr $filecount + 1)
    else
	echo "###### FAILED" 1>&2
	globalerror=$error
    filecount=$(expr $filecount + 1)
    failurecount=$(expr $failurecount + 1)
    fi
}

while getopts kdpsh c; do
    case $c in
	k) # Keep intermediate files
	    keep=1
	    ;;
	h) # Help
	    Usage
	    ;;
    esac
done

shift `expr $OPTIND - 1`

LLIFail() {
  echo "Could not find the LLVM interpreter \"$LLI\"."
  echo "Check your LLVM installation and/or modify the LLI variable in testall.sh"
  exit 1
}

which "$LLI" >> $globallog || LLIFail


if [ $# -ge 1 ]
then
    files=$@
else
    #files="compiler_tests/test-*.JSTEM compiler_tests/fail-*.JSTEM"
    files="compiler_tests/test-*.JSTEM"
fi

echo "TESTING COMPILER"

for file in $files
do
    case $file in
	*test-*)
	    Check $file 2>> $globallog
	    ;;
	*fail-*)
	    CheckFail $file 2>> $globallog
	    ;;
	*)
	    echo "unknown file type $file"
	    globalerror=1
	    ;;
    esac
done

successcount=$(($filecount-$failurecount))
echo "$successcount $filecount" | awk '{printf "PASS RATE: (%.4f) \n", $1/$2}'

exit $globalerror
