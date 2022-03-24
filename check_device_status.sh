#!/usr/bin/env bash
# check_device_status.sh
# Kazunori WAKI

#set -n
#set -x
#set -v
#set -e
#set -u

# to_json
#  output json from an associated array
#  $1 reference name of an associated array
function to_json {
    local -n dict=$1
    for i in "${!dict[@]}"; do
	echo "$i"
	echo "${dict[$i]}"
    done |
	jq -n -R 'reduce inputs as $i ({}; . + { ($i): input })'
}

# make_json_dict
#  set json properties by the specified arguments
#  $1 reference name of an associated array
#  $2 device type
#  $3 device model
#  $4 device individual_name
function make_json_dict {
    local -n dict=$1
    dict["device_status"]=0
    dict["device_type"]=$2
    dict["device_model"]=$3
    dict["device_individual_name"]=$4
    dict["device_if"]=""
    dict["device_ip"]=""
    dict["device_serial"]=""
    dict["device_message"]=""
}


#### For this script
SCRIPT_EXIT_STATUS=0
test=0

#### For JSON output
output=normal
declare -a jsons=()   # names of associated arrays for output jsons

function help() {
    echo "Usage: "
    echo ""
    echo "-h         show this help "
    echo "-j         output in json format"
    echo "-t         test"
}

while getopts "hjt" opt; do
    case $opt in
	h)
	    help
	    exit
	    ;;
	j)
	    output=json
	    ;;
	t)
	    test=1
	    ;;
    esac
done

#### For CaBot Env
scriptdir=`dirname $0`
# docker-compose will treat the .env file
if [ $test -eq 0 ] && [ -f ${scriptdir}/.env ]; then
  source ${scriptdir}/.env
fi

#### For gettext Env
source gettext.sh
export TEXTDOMAIN=check_device_status
export TEXTDOMAINDIR=${scriptdir}/locale


#### For Velodyne LiDAR Env
: ${LIDAR_IF:-''}
: ${LIDAR_IP:-''}
ARPSCAN_LIDAR='Velodyne'
ARPSCAN_BIN=`which arp-scan`
NMCLI_BIN=`which nmcli`

#### For RealSense Env
RS_ENUMERATE_DEVICES_BIN=`which rs-enumerate-devices`

: ${CABOT_REALSENSE_SERIAL_1:-''}
: ${CABOT_REALSENSE_SERIAL_2:-''}
: ${CABOT_REALSENSE_SERIAL_3:-''}
: ${CABOT_CAMERA_NAME_1:-''}
: ${CABOT_CAMERA_NAME_2:-''}
: ${CABOT_CAMERA_NAME_3:-''}

declare -A cabot_realsense_serial_map=()
if [[ -n $CABOT_REALSENSE_SERIAL_1 ]]; then
    cabot_realsense_serial_map[$CABOT_REALSENSE_SERIAL_1]=$CABOT_CAMERA_NAME_1
fi
if [[ -n $CABOT_REALSENSE_SERIAL_2 ]]; then
    cabot_realsense_serial_map[$CABOT_REALSENSE_SERIAL_2]=$CABOT_CAMERA_NAME_2
fi
if [[ -n $CABOT_REALSENSE_SERIAL_3 ]]; then
    cabot_realsense_serial_map[$CABOT_REALSENSE_SERIAL_3]=$CABOT_CAMERA_NAME_3
fi

#### Jetson Mate
: ${CABOT_JETSON_CONFIG:-''}
: ${CABOT_USER_NAME:-'cabot'}
: ${CABOT_ID_FILE:-'id_ed25519_cabot'}

#### For Odrive Env
ODRIVE_DEV_NAME='ttyODRIVE'

#### For Micro Controller Env
: ${MICRO_CONTROLLER:=''}
declare -A MICRO_CONTROLLER_DEV_NAMES=(
    ['Arduino']='ttyARDUINO_MEGA'
    ['ESP32']='ttyESP32'
)


#### For Velodyne LiDAR Prg
function check_lidar() {
  lidar_con=()

  if [[ -z $LIDAR_IF ]] || [[ -z $LIDAR_IP ]]; then
    network_interfaces=($LIDAR_IF)
    if [[ -z $LIDAR_IF ]]; then
        network_interfaces=$($NMCLI_BIN -t d | grep ':ethernet:connected:' | cut -f 1 -d ':')
    fi

    if [ ${#network_interfaces[*]} -eq 0 ]; then
      echo "$(eval_gettext "LiDAR:not_found:nmcli")"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found:nmcli")"
      return 1
    fi

    num_lidar=0
    for lidar_scan_if in ${network_interfaces[@]}
    do
      lidar_scan_ip=''
      lidar_scan_ip=`$ARPSCAN_BIN -x -l -I $lidar_scan_if 2> /dev/null | grep "$ARPSCAN_LIDAR" | cut -f1`
      if [ -n "$lidar_scan_ip" ]; then
        num_lidar=$((num_lidar += 1))
        echo -n "$(eval_gettext "LiDAR:connected:")"
        echo "${lidar_scan_if}:${lidar_scan_ip}"
	lidar_device_info["device_ip"]=${lidar_scan_ip}
	lidar_device_info["device_if"]=${lidar_scan_if}
        lidar_device_info["device_message"]="$(eval_gettext "LiDAR:connected:")"
      fi
    done

    if [ $num_lidar -eq 0 ]; then
      echo -n "$(eval_gettext "LiDAR:not_found:arp-scan:")"
      echo "${lidar_con[@]}:"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found:arp-scan:")"
      return 1
    fi

  else
    lidar_scan_ip=''
    lidar_scan_ip=`$ARPSCAN_BIN -x -I $LIDAR_IF $LIDAR_IP 2> /dev/null | grep "$ARPSCAN_LIDAR"`
    if [ -z "$lidar_scan_ip" ]; then
      echo "$(eval_gettext "LiDAR:not_found:arp-scan:")"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found:arp-scan:")"
      return 1
    fi

    echo -n "$(eval_gettext "LiDAR:connected:")"
    echo "${LIDAR_IF}:${LIDAR_IP}"

    lidar_device_info["device_ip"]=${LIDAR_IF}
    lidar_device_info["device_if"]=${LIDAR_IP}
    lidar_device_info["device_message"]="$(eval_gettext "LiDAR:connected:")"

  fi
  return 0
}

#### For RealSense Prg
function check_realsense_without_serial() {
  local -n realsense_device_info=$1
  local -n realsense_array=$2
  readarray realsense_arr< <($RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -f1,2)

  if [ ${#realsense_array[*]} -eq 0 ]; then
      realsense_device_info["device_status"]=1
      realsense_device_info["device_message"]="$(eval_gettext "RealSense:not_found:without_serial:rs-enumerate-devices")"
      echo "$(eval_gettext "RealSense:not_found:without_serial:rs-enumerate-devices")"
      return 1
  elif [ ${#realsense_array[*]} -eq 1 ]; then
      model=$(echo "${realsense_arr[0]}" | cut -f1)
      serial=$(echo "${realsense_arr[0]}" | cut -f2)
      realsense_device_info["device_status"]=0
      realsense_device_info["device_message"]="$(eval_gettext "RealSense:found:without_serial:1:")"
      realsense_device_info["device_model"]=$model
      realsense_device_info["device_serial"]=$serial
      echo -n "$(eval_gettext "RealSense:found:without_serial:1:")"
      echo "${model}:${serial}"
      return 0
  else
      realsense_device_info["device_status"]=1
      realsense_device_info["device_message"]="$(eval_gettext "RealSense:found_more_than_one:")"
      echo "$(eval_gettext "RealSense:found_more_than_one:")"
      return 1
  fi
}

function check_realsense_with_serial() {
  local -n realsense_device_info=$1
  local -n realsense_array=$2
  serial=$3
  realsense_device_info["device_serial"]=$serial
  for realsense in "${realsense_array[@]}"; do
      rmodel=$(echo "$realsense" | cut -f1)
      rserial=$(echo "$realsense" | cut -f2)

      if [[ $rserial == $serial ]]; then
	  realsense_device_info["device_status"]=0
	  realsense_device_info["device_model"]=$rmodel
	  realsense_device_info["device_message"]="$(eval_gettext "RealSense:found:with_serial:")"
	  echo -n "$(eval_gettext "RealSense:found:with_serial:")"
          echo "${rmodel}:${rserial}"
	  return 0
      fi
  done
  realsense_device_info["device_status"]=1
  realsense_device_info["device_message"]="$(eval_gettext "RealSense:not_found:with_serial:rs-enumerate-devices")"
  echo -n "$(eval_gettext "RealSense:not_found:with_serial:rs-enumerate-devices")"
  echo "$serial"
  return 1
}


#### For tty (ODrive or Arduinot or ESP32 Prg
##########################
function check_tty() {
  local -n dict_name=$1
  name=$2
  tty_name=$3

  if [ ! -L /dev/$tty_name ]; then
    echo "${name}$(eval_gettext ":dev_link_not_found_err:")"
    dict_name["device_status"]=1
    dict_name["device_message"]="${name}$(eval_gettext ":dev_link_not_found_err:")"
    return 1
  fi
  dev_name_linked=`readlink /dev/$tty_name`
  if [[ -z $dev_name_linked ]] || [ ! -e /dev/${dev_name_linked} ]; then
    echo "${name}$(eval_gettext ":dev_file_not_found_err:")"
    dict_name["device_status"]=1
    dict_name["device_message"]="${name}$(eval_gettext ":dev_file_not_found_err:")"
    return 1
  fi

  udev_output=$(udevadm info /dev/${dev_name_linked})
  readarray -t usb_name< <(echo "$udev_output" | sed -n -E "s/(E: ID_VENDOR_FROM_DATABASE=|E: ID_MODEL_FROM_DATABASE=)//p")
  serial=$(echo "$udev_output" | sed -n -E "s/(E: ID_SERIAL_SHORT=)//p" | tr -d '\n')

  dict_name["device_message"]="${name}$(eval_gettext ":usb_connected:")"
  dict_name["device_model"]=${usb_name[@]}
  dict_name["device_serial"]=${serial}
  echo -n "${name}$(eval_gettext ":usb_connected:")"
  echo "${usb_name[*]}"

  return 0
}


## redirect output to /dev/null if $output is json
redirect=
if [[ $output == "json" ]]; then
    redirect="> /dev/null"
fi

## if there is no jetson mate check realsense on host machine
if [[ -z $CABOT_JETSON_CONFIG ]]; then
    ## REALSENSE
    ## no serial number is specified  then expects one realsense
    readarray realsense_arr< <($RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -f1,2)
    if [ ${#cabot_realsense_serial_map[*]} -eq 0 ]; then
	declare -A realsense_info
	make_json_dict realsense_info "Camera" "" ""
	jsons+=(realsense_info)
	eval "check_realsense_without_serial realsense_info realsense_arr $redirect"
	SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
    else ## otherwise, check each serial number
	for serial in ${!cabot_realsense_serial_map[*]}; do
	    declare -A realsense_info_$serial
	    make_json_dict realsense_info_$serial "Camera" "" ${cabot_realsense_serial_map[$serial]}
	    jsons+=(realsense_info_$serial)
	    eval "check_realsense_with_serial realsense_info_$serial realsense_arr $serial  $redirect"
	    SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
	done
    fi
fi
## launch check jetson
if [[ -n $CABOT_JETSON_CONFIG ]]; then
    declare -A jetson_map
    ipaddresses=($(echo $CABOT_JETSON_CONFIG | cut -d':' -f2,4,6 --output-delimiter=' '))
    fid=3
    for ipaddress in "${ipaddresses[@]}"; do
	ping -c 1 -W 0.1 $ipaddress > /dev/null
	if [ $? -ne 0 ]; then
	    error=1
	    jetson_map[$ipaddress]=0
	else
	    exec {fid}< <(ssh -l $CABOT_USER_NAME -i /root/.ssh/$CABOT_ID_FILE $ipaddress lsusb 2> /dev/null)
	    jetson_map["$ipaddress"]=$fid
	fi
	fid=$((fid+1))
    done
fi


## LIDAR
declare -A lidar_device_info
make_json_dict lidar_device_info "LiDAR" $ARPSCAN_LIDAR ""
jsons+=(lidar_device_info)
eval "check_lidar $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))

## ODRIVE
declare -A odrive_device_info
make_json_dict odrive_device_info "Motor Controller" "" ""
jsons+=(odrive_device_info)
eval "check_tty odrive_device_info ODrive $ODRIVE_DEV_NAME $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))

## ARDUINO or ESP32
declare -A mc_info
make_json_dict mc_info "Micro Controller" "" ""
jsons+=(mc_info)
# if MICRO_CONTROLLER is specified
if [[ -n $MICRO_CONTROLLER ]]; then
    name=$MICRO_CONTROLLER
    tty_name=${MICRO_CONTROLLER_DEV_NAMES[$name]}
    eval "check_tty mc_info $name $tty_name $redirect"
else
    # otherwise, check Arduino first
    name="Arduino"
    tty_name=${MICRO_CONTROLLER_DEV_NAMES[$name]}
    temp=$(eval "check_tty mc_info $name $tty_name $redirect")
    if [ $? -eq 0 ]; then
	eval "check_tty mc_info $name $tty_name $redirect"
    else
	# if not found check ESP32
	name="ESP32"
	tty_name=${MICRO_CONTROLLER_DEV_NAMES[$name]}
	temp=$(eval "check_tty mc_info $name $tty_name $redirect")
	if [ $? -eq 0 ]; then
	    eval "check_tty mc_info $name $tty_name $redirect"
	else
	    echo "$(eval_gettext "no_micro_controller_found")"
	    mc_info["device_status"]=1
	    mc_info["device_message"]="$(eval_gettext "no_micro_controller_found")"
	    SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+1))
	fi
    fi
fi

## check jetson result later
for ipaddress in "${!jetson_map[@]}"; do
    fid=${jetson_map[$ipaddress]}
    declare -A jetson_${fid}
    make_json_dict jetson_${fid} "Jetson" "" ""
    jsons+=(jetson_${fid})
    declare -n dict=jetson_${fid}
    dict["device_ip"]="$ipaddress"
    if [[ $fid -ne 0 ]]; then
	result=$(cat <&${fid} | grep -E "Bus 00.*Intel Corp.")
	if [[ -n $result ]]; then
	    if [[ -n $(echo $result | grep "Bus 002") ]]; then
		dict["device_message"]="$(eval_gettext "jetson:realsense on USB3 is found")"
		eval "echo '$(eval_gettext 'jetson:realsense on USB3 is found')' $redirect"
	    else
		dict["device_message"]="$(eval_gettext "jetson:realsense on USB2 is found")"
		eval "echo '$(eval_gettext 'jetson:realsense on USB2 is found')' $redirect"
	    fi
	else
	    dict["device_status"]=1
	    dict["device_message"]="$(eval_gettext "jetson:realsense is not found")"
	    eval "echo '$(eval_gettext 'jetson:realsense is not found')' $redirect"
	    SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+1))
	fi
    else
	dict["device_status"]=1
	dict["device_message"]="$(eval_gettext "jetson:could not connect")"
	eval "echo '$(eval_gettext 'jetson:could not connect')' $redirect"
	SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+1))
    fi
done

## JSON
if [[ $output == "json" ]]; then
    # build devices array
    declare -a res
    for json in ${jsons[@]}; do
	res+=($(to_json $json))
    done
    inner=$(echo ${res[@]} | jq -s .)
    # compose json
    jq -n --arg     "cabot_device_status" $SCRIPT_EXIT_STATUS \
          --arg     "lang"                "ja_JP.UTF-8" \
          --argjson "devices"             "$inner" \
	  -M \
          '$ARGS.named'
fi

exit $SCRIPT_EXIT_STATUS
