#!/bin/bash

function red {
    echo -en "\033[31m"  ## red
    echo $@
    echo -en "\033[0m"  ## reset color
}

function help() {
    echo "Usage: "
    echo ""
    echo "-h         show this help "
    echo "-j         output in json format"
}

output=normal

while getopts "hj" opt; do
    case $opt in
	h)
	    help
	    exit
	    ;;
	j)
	    output=json
	    ;;
    esac
done


pwd=`dirname $0`
cd $pwd
scriptdir=$(pwd)

declare -a testcases=("1:1:1:2" "1:2:1:1" "1:3:1:2" "1:4:1:2" "2:1:1:1" "2:2:1:0" "2:3:1:1" "2:4:1:1" "1:1:2:4" "1:2:2:3" "1:3:2:2" "1:4:2:1" "2:1:2:3" "2:2:2:2" "2:3:2:1" "2:4:2:0")


ODRIVE_DEV_NAME='ttyODRIVE'
dummy0=0
ARDUINO_DEV_NAME='ttyARDUINO_MEGA'
dummy1=0
ESP32_DEV_NAME='ttyESP32'
dummy2=0

if [ ! -e /dev/$ODRIVE_DEV_NAME ]; then
    sudo touch /dev/ttyDUMMY0
    sudo ln -sf ttyDUMMY0 /dev/$ODRIVE_DEV_NAME
    dummy0=1
fi
if [ ! -e /dev/$ARDUINO_DEV_NAME ]; then
    sudo touch /dev/ttyDUMMY1
    sudo ln -sf ttyDUMMY1 /dev/$ARDUINO_DEV_NAME
    dummy1=1
fi
if [ ! -e /dev/$ESP32_DEV_NAME ]; then
    sudo touch /dev/ttyDUMMY2
    sudo ln -sf ttyDUMMY2 /dev/$ESP32_DEV_NAME
    dummy2=1
fi

export PATH=$(pwd):$PATH

mkdir -p $scriptdir/json
rm $scriptdir/json/*

for testcase in ${testcases[*]}
do
    IFS=":"; declare -a target=(${testcase[*]})
    
    export AS_TEST_CASE=${target[0]}
    export RS_TEST_CASE=${target[1]}
    export ENV_TEST_CASE=${target[2]}

    source ./env.sh

    expect=${target[3]}
    jsonfile=$scriptdir/json/${AS_TEST_CASE}-${RS_TEST_CASE}-${ENV_TEST_CASE}.json
    if [[ $output == "normal" ]]; then
       OUTPUT=$($scriptdir/../check_device_status.sh -t ) # -j > $jsonfile)
    else
       OUTPUT=$($scriptdir/../check_device_status.sh -t -j > $jsonfile)
    fi
    result=$?
    if [ $result -eq $expect ]; then
	echo "-------Text case $testcase (result=$result, expect=$expect): SUCCESS ----"
	echo $OUTPUT
    else
	red  "-------Text case $testcase (result=$result, expect=$expect): FAIL -------"
	red $OUTPUT
    fi

    # check if all device has message in json
    if [ -e $jsonfile ]; then
	if [ $(jq '.devices[] | select(.device_message=="")' $jsonfile | wc -l) -ne 0 ]; then
	    red "some device_message is missing in $jsonfile"
	    jq '.devices[] | select(.device_message=="")' $jsonfile
	fi
    fi
done

if [ $dummy0 -eq 1 ]; then
    sudo rm /dev/ttyDUMMY0
    sudo rm /dev/$ODRIVE_DEV_NAME
fi
if [ $dummy1 -eq 1 ]; then
    sudo rm /dev/ttyDUMMY1
    sudo rm /dev/$ARDUINO_DEV_NAME
fi
if [ $dummy2 -eq 1 ]; then
    sudo rm /dev/ttyDUMMY2
    sudo rm /dev/$ESP32_DEV_NAME
fi

