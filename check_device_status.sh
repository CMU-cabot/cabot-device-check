#!/usr/bin/env bash
# check_device_status.sh
# Kazunori WAKI

#set -n
#set -x
#set -v
set -e
set -u

#### For CaBot Env
if [ -f ~/cabot/docker/.env ]; then
  source ~/cabot/docker/.env
fi

#### For gettext Env
source gettext.sh
export TEXTDOMAIN=check_device_status
#export TEXTDOMAINDIR=${HOME}/locale
export TEXTDOMAINDIR=${HOME}/Miraikan/locale

#### For this script
SCRIPT_EXIT_STATUS=0

#### For Velodyne LiDAR Env
# env for test.
LIDAR_IF=''
LIDAR_IP=''
#LIDAR_IF=''
#LIDAR_IP=''
ARPSCAN_LIDAR='Velodyne'
#ARPSCAN_LIDAR="Velodyne\|OtherLiDARname" # for multi word
ARPSCAN_BIN=`which arp-scan`
NMCLI_BIN=`which nmcli`

#### For RealSense Env
ARPSCAN_BIN=`which arp-scan`
RS_ENUMERATE_DEVICES_BIN=`which rs-enumerate-devices`
#REALSENSE_GENESYS_LSUSB_NAME='xxxx'
#REALSENSE_INTEL_LSUSB_NAME='xxxx'

#### For Odrive Env
ODRIVE_DEV_NAME='ttyODRIVE'
ODRIVE_LSUSB_NAME='Generic ODrive Robotics ODrive v3'
ODRIVE_IF_LSUSB_NAME='Elecom Co., Ltd ODrive 3.6 CDC Interface'

#### For Arduino Env
ARDUINO_DEV_NAME='ttyARDUINO_MEGA'
ARDUINO_LSUSB_NAME='Arduino SA Mega 2560 R3 (CDC ACM)'

#### For Velodyne LiDAR Prg
lidar_con=()

if [ -z "$LIDAR_IF" ] || [ -z "$LIDAR_IP" ]; then
  if [ -n "$NMCLI_BIN" ]; then
    if [ `$NMCLI_BIN -t d | grep ':ethernet:connected:' | wc -l` != '0' ]; then
      lidar_con=(`$NMCLI_BIN -t d | grep ':ethernet:connected:' | cut -f 1 -d ':'`)
      num_lidar=0
      for lidar_scan_if in ${lidar_con[@]}
      do
        lidar_scan_ip=''
        lidar_scan_ip=`$ARPSCAN_BIN -x -l -I $lidar_scan_if | grep "$ARPSCAN_LIDAR"`
        if [ -n "$lidar_scan_ip" ]; then
          num_lidar=$((num_lidar += 1))
          echo "$(eval_gettext "LiDAR:connected:${lidar_scan_if}:${lidar_scan_ip}")"
        fi
      done
      if [ $num_lidar -eq 0 ]; then
        echo "$(eval_gettext "LiDAR:not_found:${lidar_scan_if}:")"
        SCRIPT_EXIT_STATUS=1
#        exit $SCRIPT_EXIT_STATUS
      fi
    else
      echo "$(eval_gettext "LiDAR:not_found::")"
      SCRIPT_EXIT_STATUS=1
#      exit $SCRIPT_EXIT_STATUS
    fi
  else
    echo "$(eval_gettext "LiDAR:nmcli_err::")"
    SCRIPT_EXIT_STATUS=1
#    exit $SCRIPT_EXIT_STATUS
  fi
else
  lidar_scan_ip=''
  lidar_scan_ip=`$ARPSCAN_BIN -x -l -I $LIDAR_IF $LIDAR_IP | grep "$ARPSCAN_LIDAR"`
  if [ -n "$lidar_scan_ip" ]; then
    echo "$(eval_gettext "LiDAR:connected:${LIDAR_IF}:${LIDAR_IP}")"
  else
    echo "$(eval_gettext "LiDAR:not_found::")"
    SCRIPT_EXIT_STATUS=1
#    exit $SCRIPT_EXIT_STATUS
  fi
fi

#exit $SCRIPT_EXIT_STATUS

#### For RealSense Prg

if [ -n "$RS_ENUMERATE_DEVICES_BIN" ]; then
  realsense_name_arr=()
  realsense_name_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -d '	' -f 1`)
  realsense_serial_arr=()
  realsense_serial_arr=(`$RS_ENUMERATE_DEVICES_BIN -s | tail -n +2 | sed -E 's/ {2,}/\t/g' | cut -d '	' -f 2`)

  if [ ${#realsense_serial_arr[*]} -ne 0 ]; then
    for ((realsense_serial_num=0; realsense_serial_num < ${#realsense_serial_arr[*]}; realsense_serial_num++))
    do
      echo "$(eval_gettext "RealSense:connected:${realsense_name_arr[${realsense_serial_num}]}:${realsense_serial_arr[${realsense_serial_num}]}")"
    done
  else
    echo "$(eval_gettext "RealSense:not_found::")"
    SCRIPT_EXIT_STATUS=1
#    exit $SCRIPT_EXIT_STATUS
  fi
else
  echo "$(eval_gettext "RealSense:rs_enumerate_devices_command_err::")"
  SCRIPT_EXIT_STATUS=1
#  exit $SCRIPT_EXIT_STATUS
fi

#exit $SCRIPT_EXIT_STATUS

#### For Odrive Prg
odrive_lsusb_res=''
odrive_if_lsusb_res=''
if [ -n "$ODRIVE_DEV_NAME" ]; then
  if [ -L /dev/${ODRIVE_DEV_NAME} ]; then
    odrive_dev_name_linked=`readlink /dev/${ODRIVE_DEV_NAME}`
    if [ -a /dev/${odrive_dev_name_linked} ]; then
      odrive_dev_permission=`ls -l /dev/${odrive_dev_name_linked} | cut -f 1 -d ' ' | sed -E 's/^.//g'`
      if [ "${odrive_dev_permission}" != "rw-rw-rw-" ]; then
        chmod 666 /dev/${odrive_dev_name_linked}
        if [ $? -ne 0 ]; then
          echo "$(eval_gettext "ODrive:dev_file_permission_err::")"
          SCRIPT_EXIT_STATUS=1
#          exit $SCRIPT_EXIT_STATUS
        else
          echo "$(eval_gettext "ODrive:dev_file_permission_fixed::")"
        fi
      fi
      odrive_lsusb_res=`lsusb | grep "${ODRIVE_LSUSB_NAME}"`
      odrive_if_lsusb_res=`lsusb | grep "${ODRIVE_IF_LSUSB_NAME}"`
      if [ -n "$odrive_lsusb_res" ] && [ -n "$odrive_if_lsusb_res" ];then
        echo "$(eval_gettext "ODrive:usb_connected:${odrive_lsusb_res}:${odrive_if_lsusb_res}")"

##### script for ODrivetool.

      else
        echo "$(eval_gettext "ODrive:lsusb_err::")"
        SCRIPT_EXIT_STATUS=1
#        exit $SCRIPT_EXIT_STATUS
      fi
    else
      echo "$(eval_gettext "ODrive:dev_file_not_found_err::")"
      SCRIPT_EXIT_STATUS=1
#      exit $SCRIPT_EXIT_STATUS
    fi
  else
    echo "$(eval_gettext "ODrive:dev_link_not_found_err::")"
    SCRIPT_EXIT_STATUS=1
#    exit $SCRIPT_EXIT_STATUS
  fi
else
  echo "$(eval_gettext "ODrive:odrive_dev_name_err::")"
  SCRIPT_EXIT_STATUS=1
#  exit $SCRIPT_EXIT_STATUS
fi

#exit $SCRIPT_EXIT_STATUS

#### For Arduino Prg
##########################
arduino_lsusb_res=''
if [ -n "$ARDUINO_DEV_NAME" ]; then
  if [ -L /dev/${ARDUINO_DEV_NAME} ]; then
    arduino_dev_name_linked=`readlink /dev/${ARDUINO_DEV_NAME}`
    if [ -a /dev/${arduino_dev_name_linked} ]; then
      arduino_dev_permission=`ls -l /dev/${arduino_dev_name_linked} | cut -f 1 -d ' ' | sed -E 's/^.//g'`
      if [ "${arduino_dev_permission}" != "rw-rw-rw-" ]; then
        chmod 666 /dev/${arduino_dev_name_linked}
        if [ $? -ne 0 ]; then
          echo "$(eval_gettext "Arduino:dev_file_permission_err::")"
          SCRIPT_EXIT_STATUS=1
#          exit $SCRIPT_EXIT_STATUS
        else
          echo "$(eval_gettext "Arduino:dev_file_permission_fixed::")"
        fi
      fi
      arduino_lsusb_res=`lsusb | grep "${ARDUINO_LSUSB_NAME}"`
      if [ -n "$arduino_lsusb_res" ]; then
        echo "$(eval_gettext "Arduino:usb_connected:${arduino_lsusb_res}:}")"

##### script for Arduino rostopic.

      else
        echo "$(eval_gettext "Arduino:lsusb_err::")"
        SCRIPT_EXIT_STATUS=1
#        exit $SCRIPT_EXIT_STATUS
      fi
    else
      echo "$(eval_gettext "Arduino:dev_file_not_found_err::")"
      SCRIPT_EXIT_STATUS=1
#      exit $SCRIPT_EXIT_STATUS
    fi
  else
    echo "$(eval_gettext "Arduino:dev_link_not_found_err::")"
    SCRIPT_EXIT_STATUS=1
#    exit $SCRIPT_EXIT_STATUS
  fi
else
  echo "$(eval_gettext "Arduino:arduino_dev_name_err::")"
  SCRIPT_EXIT_STATUS=1
#  exit $SCRIPT_EXIT_STATUS
fi
##########################
exit $SCRIPT_EXIT_STATUS
