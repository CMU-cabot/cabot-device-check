#!/usr/bin/env python3
#CaBot-odrive-diag.py
#Kazunori WAKI
#References
#1. https://github.com/odriverobotics/ODrive/blob/master/tools/odrive_demo.py
#2. https://docs.odriverobotics.com/v/latest/getting-started.html
#3. https://githubhot.com/repo/odriverobotics/ODrive/issues/636
#4. https://github.com/odriverobotics/ODrive/blob/master/docs/troubleshooting.rst
#5. https://github.com/odriverobotics/ODrive/blob/master/Firmware/odrive-interface.yaml

from __future__ import print_function
import odrive
from odrive.utils import *

import gettext
import os
import sys

# Find a connected ODrive (this will block until you connect one)
exit_code = 0
print("finding an odrive...")
try:
  odrv0 = odrive.find_any(timeout=3)
  if str(odrv0) == "None":
    print("ODrivetool:not_found_find_any_2::")
    exit_code = 1
  else:
    print("ODrivetool:found_find_any_2:serial_no:" + str(odrv0.serial_number))
    if (odrv0.can.error + odrv0.axis0.error + odrv0.axis0.error) == 0:
      print("ODrivetool:odrivetool_have_no_err:" + str(odrv0.serial_number)  + ":")
#      dump_errors(odrv0)
    else:
      print("ODrivetool:odrivetool_have_err:" + str(odrv0.serial_number)  + ":" + str(odrv0.can.error + odrv0.axis0.error + odrv0.axis1.error))
      dump_errors(odrv0)
      exit_code = 1

except Exception as e:
  print(e)
  exit_code = 1

sys.exit(exit_code)

# Calibrate motor and wait for it to finish
#print("starting calibration...")
#my_drive.axis0.requested_state = AXIS_STATE_FULL_CALIBRATION_SEQUENCE
#while my_drive.axis0.current_state != AXIS_STATE_IDLE:
#    time.sleep(0.1)

#my_drive.axis0.requested_state = AXIS_STATE_CLOSED_LOOP_CONTROL

# To read a value, simply read the property
#print("Bus voltage is " + str(my_drive.vbus_voltage) + "V")

# Or to change a value, just assign to the property
#my_drive.axis0.controller.input_pos = 3.14
#print("Position setpoint is " + str(my_drive.axis0.controller.pos_setpoint))

# And this is how function calls are done:
#for i in [1,2,3,4]:
#    print('voltage on GPIO{} is {} Volt'.format(i, my_drive.get_adc_voltage(i)))

# A sine wave to test
#t0 = time.monotonic()
#while True:
#    setpoint = 4.0 * math.sin((time.monotonic() - t0)*2)
#    print("goto " + str(int(setpoint)))
#    my_drive.axis0.controller.input_pos = setpoint
#    time.sleep(0.01)
