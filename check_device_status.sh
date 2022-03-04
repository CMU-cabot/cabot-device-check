#!/usr/bin/env bash
# check_device_status.sh
# Kazunori WAKI

#set -n
#set -x
#set -v
#set -e
#set -u

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

#### For Velodyne LiDAR Env
: ${LIDAR_IF:-''}
: ${LIDAR_IP:-''}
ARPSCAN_LIDAR='Velodyne'
#ARPSCAN_LIDAR="Velodyne\|OtherLiDARname" # for multi word
ARPSCAN_BIN=`which arp-scan`
NMCLI_BIN=`which nmcli`

#### For RealSense Env
ARPSCAN_BIN=`which arp-scan`
RS_ENUMERATE_DEVICES_BIN=`which rs-enumerate-devices`

: ${CABOT_REALSENSE_SERIAL_1:-''}
: ${CABOT_REALSENSE_SERIAL_2:-''}
: ${CABOT_REALSENSE_SERIAL_3:-''}
: ${CABOT_CAMERA_NAME_1:-''}
: ${CABOT_CAMERA_NAME_2:-''}
: ${CABOT_CAMERA_NAME_3:-''}

declare -a cabot_realsense_serial_arr=("${CABOT_REALSENSE_SERIAL_1}" "${CABOT_REALSENSE_SERIAL_2}" "${CABOT_REALSENSE_SERIAL_3}")
declare -a cabot_camera_name_arr=("${CABOT_CAMERA_NAME_1}" "${CABOT_CAMERA_NAME_2}" "${CABOT_CAMERA_NAME_3}")

#### For Odrive Env
ODRIVE_DEV_NAME='ttyODRIVE'
ODRIVE_LSUSB_NAME='Generic ODrive Robotics ODrive v3'

#### For Arduino Env
ARDUINO_DEV_NAME='ttyARDUINO_MEGA'
ARDUINO_LSUSB_NAME='Arduino SA Mega 2560 R3 (CDC ACM)'

#### For Velodyne LiDAR Prg

function check_lidar() {
  lidar_con=()

  if [ -z "$LIDAR_IF" ] || [ -z "$LIDAR_IP" ]; then


    if [ `$NMCLI_BIN -t d | grep ':ethernet:connected:' | wc -l` == '0' ]; then
      echo "$(eval_gettext "LiDAR:not_found::")"
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
      fi
    done

    if [ $num_lidar -eq 0 ]; then
      echo -n "$(eval_gettext "LiDAR:not_found:")"
      echo "${lidar_scan_if}:"
      return 1
    fi

  else
    lidar_scan_ip=''
    lidar_scan_ip=`$ARPSCAN_BIN -x -l -I $LIDAR_IF $LIDAR_IP | grep "$ARPSCAN_LIDAR"`
    if [ -z "$lidar_scan_ip" ]; then
      echo "$(eval_gettext "LiDAR:not_found::")"
      return 1
    fi

    echo -n "$(eval_gettext "LiDAR:connected:")"
    echo "${LIDAR_IF}:${LIDAR_IP}"
  fi
  return 0
}

#### For RealSense Prg
function check_realsense() {

  realsense_name_arr=()
  realsense_name_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -d '	' -f 1`)
  realsense_serial_arr=()
  realsense_serial_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -d '	' -f 2`)

  if [ ${#realsense_serial_arr[*]} -eq 0 ]; then
    echo "$(eval_gettext "RealSense:not_found::")"
    return 1
  fi

  for ((realsense_serial_num=0; realsense_serial_num < ${#realsense_serial_arr[*]}; realsense_serial_num++))
  do
    cabot_realsense_serial_tmp=''
    cabot_camera_name_tmp=''
    if [ "${CABOT_REALSENSE_SERIAL_1}${CABOT_REALSENSE_SERIAL_2}${CABOT_REALSENSE_SERIAL_3}" != '' ]; then
      cabot_realsense_serial_arr_num=0
      for cabot_realsense_serial_tmp in ${cabot_realsense_serial_arr[@]}; do
        if [ "${cabot_realsense_serial_arr[${cabot_realsense_serial_arr_num}]}" == "${realsense_serial_arr[${realsense_serial_num}]}" ]; then
          cabot_camera_name_tmp=${cabot_camera_name_arr[${cabot_realsense_serial_arr_num}]}
	fi
        let cabot_realsense_serial_arr_num++          
      done
    fi
    echo -n "$(eval_gettext "RealSense:connected:")"
    echo "${realsense_name_arr[${realsense_serial_num}]}:${realsense_serial_arr[${realsense_serial_num}]}:${cabot_camera_name_tmp}"
  done

  return 0
}

#### For Odrive Prg
function check_odrive() {
  odrive_lsusb_res=''
  odrive_if_lsusb_res=''
  if [ -z "$ODRIVE_DEV_NAME" ]; then
    echo "$(eval_gettext "ODrive:odrive_dev_name_err::")"
    return 1
  fi

  if [ ! -L /dev/${ODRIVE_DEV_NAME} ]; then
    echo "$(eval_gettext "ODrive:dev_link_not_found_err::")"
    return 1
  fi

  odrive_dev_name_linked=`readlink /dev/${ODRIVE_DEV_NAME}`

  if [ ! -e /dev/${odrive_dev_name_linked} ]; then
    echo "$(eval_gettext "ODrive:dev_file_not_found_err::")"
    return 1
  fi

  odrive_lsusb_res=`lsusb | grep "${ODRIVE_LSUSB_NAME}"`

  if [ -z "$odrive_lsusb_res" ] && [ -n "$odrive_if_lsusb_res" ];then
    echo "$(eval_gettext "ODrive:lsusb_err::")"
    return 1
  fi

  echo -n "$(eval_gettext "ODrive:usb_connected:")"
  echo "${odrive_lsusb_res}:${odrive_if_lsusb_res}"

##### script for ODrivetool.

  return 0
}

#### For Arduino Prg
##########################
function check_arduino() {
  arduino_lsusb_res=''
  if [ -z "$ARDUINO_DEV_NAME" ]; then
    echo "$(eval_gettext "Arduino:arduino_dev_name_err::")"
    return 1
  fi
  if [ ! -L /dev/${ARDUINO_DEV_NAME} ]; then
    echo "$(eval_gettext "Arduino:dev_link_not_found_err::")"
    return 1
  fi
  arduino_dev_name_linked=`readlink /dev/${ARDUINO_DEV_NAME}`
  if [ ! -e /dev/${arduino_dev_name_linked} ]; then
    echo "$(eval_gettext "Arduino:dev_file_not_found_err::")"
    return 1
  fi
  arduino_lsusb_res=`lsusb | grep "${ARDUINO_LSUSB_NAME}"`

  if [ -z "$arduino_lsusb_res" ]; then
    echo "$(eval_gettext "Arduino:lsusb_err::")"
    return 1
  fi
  echo -n "$(eval_gettext "Arduino:usb_connected:")"
  echo "${arduino_lsusb_res}:}"

  return 0
}


check_lidar
if [ $? -eq 1 ];then
    SCRIPT_EXIT_STATUS=1
fi

check_realsense
if [ $? -eq 1 ];then
    SCRIPT_EXIT_STATUS=1
fi

check_odrive
if [ $? -eq 1 ];then
    SCRIPT_EXIT_STATUS=1
fi

check_arduino
if [ $? -eq 1 ];then
    SCRIPT_EXIT_STATUS=1
fi

exit $SCRIPT_EXIT_STATUS
