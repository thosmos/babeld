#!/bin/bash
set -eux

CI=${CI:=""}
TEST=${TEST:=""}

check_deps()
{
        if !hash cppcheck 2>/dev/null; then
               echo "Please install cppcheck"
        fi
}

build_babel()
{
        cores=$(grep -c ^processor /proc/cpuinfo)
        make clean
        make -j $cores
	if [ $? -ne 0 ]
	then
		echo "Compile failed!"
		exit 1
        fi
}

run_lint()
{
        cppcheck --force .
	if [ $? -ne 0 ]
	then
		echo "Linting failed!"
		exit 1
        fi
        echo "Linting successful"
}

run_integration_tests()
{
        pushd tests
                sudo -E ./multihop-smoketest.sh
		if [ $? -ne 0 ]
		then
			echo "Integration test failed!"
			exit 1
		fi
        popd
}

run_compat_tests()
{
        pushd tests
		sudo -E ./multihop-compat.sh
		if [ $? -ne 0 ]
		then
			echo "Compatibility tests failed!"
			exit 1
		fi
        popd
}

if [ -z "$CI" ]; then
	check_deps
	build_babel
	run_lint
	run_integration_tests
	run_compat_tests
else
	case $TEST in
		"lint")
			run_lint
			;;
		"build")
			build_babel
			;;
		"integration")
			build_babel
			run_integration_tests
			;;
		"compat")
			run_compat_tests
			;;
		*)
			echo "Unknown test \"$TEST\" (valid values: {lint|build|integration})"
			;;
	esac
fi
