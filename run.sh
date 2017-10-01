#!/bin/sh
export ROOT=$(cd `dirname $0`; pwd)
export DAEMON=false

while getopts "dk" arg
do
	case $arg in
		d)
			export DAEMON=true
			;;
		k)
			kill `cat $ROOT/run/skynet.pid`
			exit 0;
			;;
	esac
done

$ROOT/skynet/skynet $ROOT/config/config.dev
