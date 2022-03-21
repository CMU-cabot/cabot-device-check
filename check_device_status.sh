#!/usr/bin/env bash
# check_device_status.sh
# Kazunori WAKI

#set -n
#set -x
#set -v
#set -e
#set -u

function help() {
    echo "Usage: "
    echo ""
    echo "-h         show this help "
    echo "-j         output in json format"
}

function tojson {
    local -n dict=$1

    for i in "${!dict[@]}"
    do
	echo "$i"
	echo "${dict[$i]}"
    done |
	jq -n -R 'reduce inputs as $i ({}; . + { ($i): (input|(tonumber? // .)) })'
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

#### For CaBot Env
scriptdir=`dirname $0`
if [ -f ${scriptdir}/.env ]; then
  source ${scriptdir}/.env
fi

#### For gettext Env
source gettext.sh
export TEXTDOMAIN=check_device_status
export TEXTDOMAINDIR=${scriptdir}/locale

#### For this script
SCRIPT_EXIT_STATUS=0
ARPSCAN_BIN=`which arp-scan`

#### For Velodyne LiDAR Env
: ${LIDAR_IF:-''}
: ${LIDAR_IP:-''}
ARPSCAN_LIDAR='Velodyne'
#ARPSCAN_LIDAR="Velodyne\|OtherLiDARname" # for multi word
NMCLI_BIN=`which nmcli`
declare -A lidar_device_info=(
    ["device_status"]=0
    ["device_type"]="LiDAR"
    ["device_model"]=$ARPSCAN_LIDAR
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]="" 
    ["device_individual_name"]=""
    ["device_message"]=""
)

#### For RealSense Env
RS_ENUMERATE_DEVICES_BIN=`which rs-enumerate-devices`

: ${CABOT_REALSENSE_SERIAL_1:-''}
: ${CABOT_REALSENSE_SERIAL_2:-''}
: ${CABOT_REALSENSE_SERIAL_3:-''}
: ${CABOT_CAMERA_NAME_1:-''}
: ${CABOT_CAMERA_NAME_2:-''}
: ${CABOT_CAMERA_NAME_3:-''}

declare -a cabot_realsense_serial_arr=("${CABOT_REALSENSE_SERIAL_1}" "${CABOT_REALSENSE_SERIAL_2}" "${CABOT_REALSENSE_SERIAL_3}")
declare -a cabot_camera_name_arr=("${CABOT_CAMERA_NAME_1}" "${CABOT_CAMERA_NAME_2}" "${CABOT_CAMERA_NAME_3}")

declare -a cabot_realsense_serial_arr2=("${CABOT_REALSENSE_SERIAL_1}" "${CABOT_REALSENSE_SERIAL_2}" "${CABOT_REALSENSE_SERIAL_3}")
declare -a cabot_camera_name_arr2=("${CABOT_CAMERA_NAME_1}" "${CABOT_CAMERA_NAME_2}" "${CABOT_CAMERA_NAME_3}")

declare -A realsense_device_info_1=(
    ["device_status"]=0
    ["device_type"]="Camera"
    ["device_model"]=""
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]=${cabot_realsense_serial_arr[0]}
    ["device_individual_name"]=${cabot_camera_name_arr[0]}
    ["device_message"]=""
)

declare -A realsense_device_info_2=(
    ["device_status"]=0
    ["device_type"]="Camera"
    ["device_model"]=""
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]=${cabot_realsense_serial_arr[1]}
    ["device_individual_name"]=${cabot_camera_name_arr[1]}
    ["device_message"]=""
)

declare -A realsense_device_info_3=(
    ["device_status"]=0
    ["device_type"]="Camera"
    ["device_model"]=""
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]=${cabot_realsense_serial_arr[2]}
    ["device_individual_name"]=${cabot_camera_name_arr[2]}
    ["device_message"]=""
)

#### For Odrive Env
ODRIVE_DEV_NAME='ttyODRIVE'
ODRIVE_LSUSB_NAME='Generic ODrive Robotics ODrive v3'
declare -A odrive_device_info=(
    ["device_status"]=0
    ["device_type"]="Motor Controller"
    ["device_model"]=$ODRIVE_LSUSB_NAME
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]="" 
    ["device_individual_name"]=""
    ["device_message"]=""
)

#### For Arduino Env
ARDUINO_DEV_NAME='ttyARDUINO_MEGA'
ARDUINO_LSUSB_NAME='Arduino SA Mega 2560 R3 (CDC ACM)'
declare -A arduino_device_info=(
    ["device_status"]=0
    ["device_type"]="Micro Controller"
    ["device_model"]=$ARDUINO_LSUSB_NAME
    ["device_if"]=""
    ["device_ip"]=""
    ["device_serial"]="" 
    ["device_individual_name"]=""
    ["device_message"]=""
)

#### For Velodyne LiDAR Prg
function check_lidar() {
  lidar_con=()

  if [ -z "$LIDAR_IF" ] || [ -z "$LIDAR_IP" ]; then

    if [ `$NMCLI_BIN -t d | grep ':ethernet:connected:' | wc -l` == '0' ]; then
      echo "$(eval_gettext "LiDAR:not_found::")"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found::")"
      return 1
    fi

    lidar_con=(`$NMCLI_BIN -t d | grep ':ethernet:connected:' | cut -f 1 -d ':'`)
    num_lidar=0
    for lidar_scan_if in ${lidar_con[@]}
    do
      lidar_scan_ip=''
      lidar_scan_ip=`$ARPSCAN_BIN -x -l -I $lidar_scan_if | grep "$ARPSCAN_LIDAR"`
      if [ -n "$lidar_scan_ip" ]; then
        num_lidar=$((num_lidar += 1))
        echo -n "$(eval_gettext "LiDAR:connected:")"
        echo "${lidar_scan_if}:${lidar_scan_ip}"
        lidar_device_info["device_message"]="$(eval_gettext "LiDAR:connected:")"
      fi
    done

    if [ $num_lidar -eq 0 ]; then
      echo -n "$(eval_gettext "LiDAR:not_found:")"
      echo "${lidar_scan_if}:"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found:")"
      return 1
    fi

  else
    lidar_scan_ip=''
    lidar_scan_ip=`$ARPSCAN_BIN -x -I $LIDAR_IF $LIDAR_IP | grep "$ARPSCAN_LIDAR"`
    if [ -z "$lidar_scan_ip" ]; then
      echo "$(eval_gettext "LiDAR:not_found::")"
      lidar_device_info["device_status"]=1
      lidar_device_info["device_message"]="$(eval_gettext "LiDAR:not_found::")"
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
function check_realsense() {
  ifstmp=$IFS
  IFS=$'\n'
  realsense_name_arr=()
  realsense_name_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -f 1`)

  realsense_serial_arr=()
  realsense_serial_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -f 2`)
  IFS=$ifstmp

  if [ ${#realsense_serial_arr[*]} -eq 0 ]; then
    echo "$(eval_gettext "RealSense:not_found::")"
    realsense_device_info_1["device_status"]=1
    realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:not_found::")"
    realsense_device_info_2["device_status"]=1
    realsense_device_info_2["device_message"]="$(eval_gettext "RealSense:not_found::")"
    realsense_device_info_3["device_status"]=1
    realsense_device_info_3["device_message"]="$(eval_gettext "RealSense:not_found::")"
    return 1
  fi

  ifstmp=$IFS
  rs_serials="$(IFS=""; echo "${cabot_realsense_serial_arr[*]}")"
  IFS=$ifstmp

  if [ "${rs_serials}" == '' ]; then
    if [ ${#realsense_serial_arr[*]} -ne 1 ]; then
      echo "$(eval_gettext "RealSense:serial_env_num_err::")"
      realsense_device_info_1["device_status"]=1
      realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:serial_env_num_err::")"
      return 1
    else
      echo -n "$(eval_gettext "RealSense:connected:")"
      echo "${realsense_name_arr[0]}:${realsense_serial_arr[0]}:"
      realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:connected:")"
      realsense_device_info_1["device_model"]=${realsense_name_arr[0]}
      realsense_device_info_1["device_serial"]=${realsense_serial_arr[0]}
      return 0
    fi
  fi

  cabot_camera_name_tmp=()
  for ((realsense_serial_num=0; realsense_serial_num < ${#realsense_serial_arr[*]}; realsense_serial_num++))
  do
    cabot_realsense_serial_tmp=''
    cabot_realsense_serial_arr_num=0
    for cabot_realsense_serial_tmp in ${cabot_realsense_serial_arr[@]}; do
      if [ "${cabot_realsense_serial_tmp}" == "${realsense_serial_arr[${realsense_serial_num}]}" ]; then
        cabot_camera_name_tmp[${realsense_serial_num}]=${cabot_camera_name_arr[${cabot_realsense_serial_arr_num}]}
        cabot_realsense_serial_arr2[${cabot_realsense_serial_arr_num}]=""
        cabot_camera_name_arr2[${cabot_realsense_serial_arr_num}]=""

        if [ ${cabot_realsense_serial_arr_num} -eq 0 ]; then
          realsense_device_info_1["device_model"]=${realsense_name_arr[${cabot_realsense_serial_arr_num}]}
        fi
        if [ ${cabot_realsense_serial_arr_num} -eq 1 ]; then
          realsense_device_info_2["device_model"]=${realsense_name_arr[${cabot_realsense_serial_arr_num}]}
        fi
        if [ ${cabot_realsense_serial_arr_num} -eq 2 ]; then
          realsense_device_info_3["device_model"]=${realsense_name_arr[${cabot_realsense_serial_arr_num}]}
        fi
      fi
      let cabot_realsense_serial_arr_num++          
    done
  done

  ifstmp=$IFS
  rs_serials2="$(IFS=""; echo "${cabot_realsense_serial_arr2[*]}")"
  IFS=$ifstmp
  if [ "${rs_serials2}" != '' ]; then
    echo -n "$(eval_gettext "RealSense:not_found::")"
    echo "${cabot_realsense_serial_arr2[*]}:${cabot_camera_name_arr2[*]}"
    if [ "${cabot_realsense_serial_arr2[0]}" != "" ]; then
      realsense_device_info_1["device_status"]=1
      realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:not_found::")"
    fi
    if [ "${cabot_realsense_serial_arr2[1]}" != "" ]; then
      realsense_device_info_2["device_status"]=1
      realsense_device_info_2["device_message"]="$(eval_gettext "RealSense:not_found::")"
    fi
    if [ "${cabot_realsense_serial_arr2[2]}" != "" ]; then
      realsense_device_info_3["device_status"]=1
      realsense_device_info_3["device_message"]="$(eval_gettext "RealSense:not_found::")"
    fi
    return 1
  else
    if [ "${cabot_realsense_serial_arr[0]}" != "" ]; then
      echo -n "$(eval_gettext "RealSense:connected:")"
      echo "${realsense_device_info_1["device_serial"]}:${realsense_device_info_1["device_model"]}"
      realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:connected:")"
    fi
    if [ "${cabot_realsense_serial_arr[0]}" != "" ]; then
      echo -n "$(eval_gettext "RealSense:connected:")"
      echo "${realsense_device_info_1["device_serial"]}:${realsense_device_info_1["device_model"]}"
      realsense_device_info_1["device_message"]="$(eval_gettext "RealSense:connected:")"
    fi
    if [ "${cabot_realsense_serial_arr[1]}" != "" ]; then
      echo -n "$(eval_gettext "RealSense:connected:")"
      echo "${realsense_device_info_2["device_serial"]}:${realsense_device_info_2["device_model"]}"
      realsense_device_info_2["device_message"]="$(eval_gettext "RealSense:connected:")"
    fi
    if [ "${cabot_realsense_serial_arr[2]}" != "" ]; then
      echo -n "$(eval_gettext "RealSense:connected:")"
      echo "${realsense_device_info_3["device_serial"]}:${realsense_device_info_3["device_model"]}"
      realsense_device_info_3["device_message"]="$(eval_gettext "RealSense:connected:")"
    fi
  fi
  return 0
}

#### For Odrive Prg
function check_odrive() {
  odrive_lsusb_res=''
  if [ -z "$ODRIVE_DEV_NAME" ]; then
    echo "$(eval_gettext "ODrive:odrive_dev_name_err::")"
    odrive_device_info["device_status"]=1
    odrive_device_info["device_message"]="$(eval_gettext "ODrive:odrive_dev_name_err::")"
    return 1
  fi

  if [ ! -L /dev/${ODRIVE_DEV_NAME} ]; then
    echo "$(eval_gettext "ODrive:dev_link_not_found_err::")"
    odrive_device_info["device_status"]=1
    odrive_device_info["device_message"]="$(eval_gettext "ODrive:dev_link_not_found_err::")"
    return 1
  fi

  odrive_dev_name_linked=`readlink /dev/${ODRIVE_DEV_NAME}`

  if [ ! -e /dev/${odrive_dev_name_linked} ]; then
    echo "$(eval_gettext "ODrive:dev_file_not_found_err::")"
    odrive_device_info["device_status"]=1
    odrive_device_info["device_message"]="$(eval_gettext "ODrive:dev_file_not_found_err::")"
    return 1
  fi

  if [ -z "${ODRIVE_LSUSB_NAME}" ]; then
    echo "$(eval_gettext "ODrive:lsusb_name_err::")"
    odrive_device_info["device_status"]=1
    odrive_device_info["device_message"]="$(eval_gettext "ODrive:lsusb_name_err::")"
    return 1
  fi

  odrive_lsusb_res=`lsusb | grep "${ODRIVE_LSUSB_NAME}"`

  if [ -z "$odrive_lsusb_res" ]; then
    echo "$(eval_gettext "ODrive:lsusb_err::")"
    odrive_device_info["device_status"]=1
    odrive_device_info["device_message"]="$(eval_gettext "ODrive:lsusb_err::")"
    return 1
  fi

##### script for ODrivetool.

  echo -n "$(eval_gettext "ODrive:connected:")"
  odrive_device_info["device_message"]="$(eval_gettext "ODrive:connected::")"

  return 0
}

#### For Arduino Prg
##########################
function check_arduino() {
  arduino_lsusb_res=''
  if [ -z "$ARDUINO_DEV_NAME" ]; then
    echo "$(eval_gettext "Arduino:arduino_dev_name_err::")"
    arduino_device_info["device_status"]=1
    arduino_device_info["device_message"]="$(eval_gettext "Arduino:arduino_dev_name_err::")"
    return 1
  fi
  if [ ! -L /dev/${ARDUINO_DEV_NAME} ]; then
    echo "$(eval_gettext "Arduino:dev_link_not_found_err::")"
    arduino_device_info["device_status"]=1
    arduino_device_info["device_message"]="$(eval_gettext "Arduino:dev_link_not_found_err::")"
    return 1
  fi
  arduino_dev_name_linked=`readlink /dev/${ARDUINO_DEV_NAME}`
  if [ ! -e /dev/${arduino_dev_name_linked} ]; then
    echo "$(eval_gettext "Arduino:dev_file_not_found_err::")"
    arduino_device_info["device_status"]=1
    arduino_device_info["device_message"]="$(eval_gettext "Arduino:dev_file_not_found_err::")"
    return 1
  fi
  arduino_lsusb_res=`lsusb | grep "${ARDUINO_LSUSB_NAME}"`

  if [ -z "$arduino_lsusb_res" ]; then
    echo "$(eval_gettext "Arduino:lsusb_err::")"
    arduino_device_info["device_status"]=1
    arduino_device_info["device_message"]="$(eval_gettext "Arduino:lsusb_err::")"
    return 1
  fi
  echo -n "$(eval_gettext "Arduino:usb_connected:")"
  echo "${arduino_lsusb_res}:"
  arduino_device_info["device_message"]="$(eval_gettext "Arduino:usb_connected:")${arduino_lsusb_res}:"
  return 0
}

function output_json() {
    lidar=$(tojson lidar_device_info)
    rs1=$(tojson realsense_device_info_1)
    if [[ ${realsense_device_info_2["device_serial"]} != "" ]]; then
	rs2=$(tojson realsense_device_info_2)
    fi
    if [[ ${realsense_device_info_3["device_serial"]} != "" ]]; then
	rs3=$(tojson realsense_device_info_3)
    fi
    odrive=$(tojson odrive_device_info)
    arduino=$(tojson arduino_device_info)
    inner=$(echo $lidar $rs1 $rs2 $rs3 $odrive $arduino | jq -s .)
    jq -n --arg "cabot_device_status" $SCRIPT_EXIT_STATUS --arg "lang" "ja_JP.UTF-8" --argjson devices "$inner" '$ARGS.named'
    return 0
}


redirect=
if [[ $output == "json" ]]; then
    redirect="> /dev/null"
fi
eval "check_lidar $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
eval "check_realsense $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
eval "check_odrive $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
eval "check_arduino $redirect"
SCRIPT_EXIT_STATUS=$((SCRIPT_EXIT_STATUS+$?))
if [[ $output == "json" ]]; then
    output_json
fi

exit $SCRIPT_EXIT_STATUS
