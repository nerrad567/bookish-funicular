# ==========================================================================================
# Script Name: toggle_touchpad.sh
# Description: This elegant script gracefully toggles the state of the SynPS/2 Synaptics 
#              TouchPad on your Linux machine. With a simple run, it checks the current 
#              status of the touchpad, and with a touch of sophistication, it either 
#              enables or disables it, providing a seamless user experience. The script
#              echoes a charming message to inform you of the touchpad's new state, ensuring
#              clear communication and a delightful interaction.
#              
# Author: https://github.com/nerrad567/bookish-funicular
# 
# Usage: ./toggle_touchpad.sh
# Dependencies: xinput (for interacting with input devices), grep, and awk.
#
# Notes: Ensure that the device name is correctly specified and that xinput is installed.
#        Run with bash and enjoy the simplicity of one-touch touchpad toggling!
# ==========================================================================================

# Get the current status of the touchpad
TOUCHPAD_STATUS=$(xinput list-props "SynPS/2 Synaptics TouchPad" | grep "Device Enabled" | awk '{print $NF}')

# Toggle the touchpad
if [ $TOUCHPAD_STATUS -eq 1 ]; then
  xinput disable "SynPS/2 Synaptics TouchPad"
  echo "Touchpad disabled"
else
  xinput enable "SynPS/2 Synaptics TouchPad"
  echo "Touchpad enabled"
fi
