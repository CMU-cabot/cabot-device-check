#!/usr/bin/env python3
#CaBot-odrive-diag.py
#Kazunori WAKI
#References
#1. https://github.com/odriverobotics/ODrive/blob/master/tools/odrive_demo.py
#2. https://docs.odriverobotics.com/v/latest/getting-started.html
#3. https://githubhot.com/repo/odriverobotics/ODrive/issues/636
#4. https://github.com/odriverobotics/ODrive/blob/master/docs/troubleshooting.rst
#5. https://github.com/odriverobotics/ODrive/blob/master/Firmware/odrive-interface.yaml
#6. https://github.com/odriverobotics/ODrive/blob/a5f4efe091c2fccb1c7e7b630e90ebf2aeb8109e/tools/odrive/__init__.py#L22-L24
#7. https://docs.python.org/ja/3.8/library/gettext.html
#8. https://docs.odriverobotics.com/v/latest/troubleshooting.html
#9. https://stackoverflow.com/questions/60826507/error-retrieving-current-directory-getcwd-in-docker-container

from __future__ import print_function
import odrive
from odrive.utils import *
from odrive.pyfibre.fibre import Event

import gettext
import os
import sys

exit_code = 0

def help():
    print("Usage: ")
    print("")
    print("-h        show this help ")
    print("-v        show verbose message")

args = sys.argv
#  args[1], args[2] ...    options (-h, -v, ... )

verbose = 0
test = 0
if len(args) > 1:
    for i in range(1, len(args)):
        if args[i] == '-h':
            help()
            sys.exit(exit_code)
        if args[i] == '-v':
            verbose = 1
 
def make_device_dict():
    dict_device=dict(
        device_serial="" ,
        device_message=""
    )
    return dict_device

# For gettext
def set_gettext():
    lang_str = os.environ.get('LANG', '')
    locale_dir_path = os.path.join(os.path.dirname(__file__),'locale')
    trans_class = gettext.translation(
        domain='CaBot-odrive-diag',
        localedir=locale_dir_path,
        languages=[lang_str],
        fallback=True
    )
    trans_class.install() 

# For gettext
set_gettext()

#dict for device.
odrive_device_info = make_device_dict()

# Find a connected ODrive (this will block until you connect one)
if verbose == 1 :
    print("finding an odrive...")

token=Event()

try:
    odrv0 = odrive.find_any(timeout=3, channel_termination_token=token)
    if str(odrv0) == "None":
        if verbose == 1:
            print(_("ODrivetool:not_found_find_any:"))
        odrive_device_info["device_message"] = _("ODrivetool:not_found_find_any:") 
        exit_code = 1
    else:
        odrive_device_info["device_serial"] = str(odrv0.serial_number)
        odrive_device_info["device_message"] = _("ODrivetool:found_find_any:serial_no:") 
        if verbose == 1:
            print(_("ODrivetool:found_find_any:serial_no:") + str(odrv0.serial_number))
        if (odrv0.can.error + odrv0.axis0.error + odrv0.axis1.error) != 0:
            odrive_device_info["device_message"] = _("ODrivetool:have_err:NumOfErr:") + str(odrv0.can.error + odrv0.axis0.error + odrv0.axis1.error)
            if verbose == 1:
                print(_("ODrivetool:have_err:NumOfErr:") + str(odrv0.can.error + odrv0.axis0.error + odrv0.axis1.error))
                dump_errors(odrv0)
            exit_code = 1

except TimeoutError:
    odrive_device_info["device_message"] = _("ODrivetool:TimeoutError:") 
    if verbose == 1:
        print(_("ODrivetool:TimeoutError:"))
    exit_code = 1 

except Exception as e:
    odrive_device_info["device_message"] = _("ODrivetool:Exception:") 
    if verbose == 1:
        print(_("ODrivetool:Exception:"))
        print(str(e))
    exit_code = 1

sys.stdout.write(str(odrive_device_info["device_serial"]) + ":" + str(odrive_device_info["device_message"]))

token.set()
sys.exit(bool(exit_code))
