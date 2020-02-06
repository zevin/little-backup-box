#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# IMPORTANT:
# Run the install-little-backup-box.sh script first
# to install the required packages and configure the system.

CONFIG_DIR=$(dirname "$0")
CONFIG="${CONFIG_DIR}/config.cfg"

OLEDBIN="/home/pi/ssd1306_rpi/oled"

source "$CONFIG"

# st599 added debugging print outs
if [ "$DEBUG" = "true" ]; then
  echo "CARD BACKUP"
  echo "Config Parser"
  echo "  Storage device      $STORAGE_DEV"
  echo "  Storage mount point $STORAGE_MOUNT_POINT"
  echo "  Card device         $CARD_DEV"
  echo "  Card mount point    $CARD_MOUNT_POINT"
  echo "  Display             $DISP"
  echo "  Syncthing           $SYNCTHING"
fi

# If display support is enabled, state programme run
if [ $DISP = true ]; then
    $OLEDBIN r
    $OLEDBIN +a "Lit. Bac. Box"
    $OLEDBIN +b "Card Backup"
    sudo $OLEDBIN s
    sleep 1
    $OLEDBIN r
    $OLEDBIN +a "Card Backup"
    $OLEDBIN +b "Storage..."
    sudo $OLEDBIN s
fi



# Set the ACT LED to heartbeat
sudo sh -c "echo heartbeat > /sys/class/leds/led0/trigger"

# Shutdown after a specified period of time (in minutes) if no device is connected.

sudo shutdown -h $SHUTD "Shutdown is activated. To cancel: sudo shutdown -c"
if [ $DISP = true ]; then
    oled r
    oled +a "Shutdown active"
    oled +b "Insert storage"
    sudo oled s
fi

# Wait for a USB storage device (e.g., a USB flash drive)
if [ "$DEBUG" = "true" ]; then
  echo "Awaiting Storage"
fi
# STORAGE=$(ls /dev/* | grep "$STORAGE_DEV" | cut -d"/" -f3)
# while [ -z "${STORAGE}" ]
# do
#     sleep 1
#     STORAGE=$(ls /dev/* | grep "$STORAGE_DEV" | cut -d"/" -f3)
# done
# # When the USB storage device is detected, mount it
# sudo mount /dev/"$STORAGE_DEV" "$STORAGE_MOUNT_POINT"

# Wait for a USB storage device (e.g., a USB flash drive)
STORAGE=$(ls /media/storage/ | grep "UUID" )
while [ -z "${STORAGE}" ]
do
    sleep 1
    STORAGE=$(ls /media/storage/ | grep "UUID" )
done
sudo chmod a+rwx "$STORAGE_MOUNT_POINT"

# Set the ACT LED to blink at 1000ms to indicate that the storage device has been mounted
sudo sh -c "echo timer > /sys/class/leds/led0/trigger"
sudo sh -c "echo 1000 > /sys/class/leds/led0/delay_on"

# If display support is enabled, notify that the storage device has been mounted
if [ $DISP = true ]; then

    $OLEDBIN r
    $OLEDBIN +a "Storage OK"
    $OLEDBIN +b "Card reader..."
    sudo $OLEDBIN s
fi

# Wait for a card reader or a camera
# takes first device found
# CARDS=("sda1" "sda2" "sdb1" "sdb2" "sdc1" "sdc2")
# CARD=""
# until [ ! -z "${CARD}" ]
#   do
#     sleep 1
#     for c in ${CARDS[@]}; do
#       set -x
#       SIZE=$(udisksctl info -b /dev/$c | grep Size: | awk '{print $2}')
#       if [ $SIZE -gt 1000 ] && [ $SIZE -lt 128000000000 ]
#         CARD=$c
#         break
#       fi
#     done
# done
CARD=""
until [ ! -z "${CARD}" ]
  do
    sleep 1
    if [ -b "$CARD_MOUNT_POINT" ]; then
      CARD="1"
      break
    fi
done

# mount /dev/"$CARD" "$CARD_MOUNT_POINT"

# If the card reader is detected, mount it and obtain its UUID
# if [ ! -z "${CARD}" ]; then
if [ -b "$CARD_MOUNT_POINT" ]; then
  # Set the ACT LED to blink at 500ms to indicate that the card has been mounted
  sudo sh -c "echo 500 > /sys/class/leds/led0/delay_on"

  # If display support is enabled, notify that the card has been mounted
  if [ $DISP = true ]; then
      $OLEDBIN r
      $OLEDBIN +a "Card reader OK"
      $OLEDBIN +b "Backup start"
      sudo $OLEDBIN s
  # Cancel shutdown
  sudo shutdown -c

  fi

  # Create  a .id random identifier file if doesn't exist
  if [ $DEBUG = true ]; then
    echo "Creating ID File"
  fi
  cd "$CARD_MOUNT_POINT"
  if [ ! -f *.id ]; then
    random=$(echo $RANDOM)
    touch $(date -d "today" +"%Y%m%d%H%M")-$random.id
  fi
  ID_FILE=$(ls *.id)
  ID="${ID_FILE%.*}"
  cd

  # Set the backup path
  BACKUP_PATH="$STORAGE_MOUNT_POINT"/"$ID"


  # Perform backup using rsync
  if [ $DEBUG = true ]; then
    echo "Perform Backup"
  fi
  if [ $DISP = true ]; then
    rsync -avh --info=progress2 --exclude "*.id" "$CARD_MOUNT_POINT"/ "$BACKUP_PATH" | /home/pi/little-backup-box/scripts/oled-rsync-progress.sh exclude.txt
  else
    rsync -avh --info=progress2 --exclude "*.id" "$CARD_MOUNT_POINT"/ "$BACKUP_PATH"
  fi
fi
if [ $DEBUG = true ]; then
  echo "Backup Complete"
fi


# If display support is enabled, notify that the backup is complete
if [ $DISP = true ]; then

    $OLEDBIN r
    $OLEDBIN +a "Complete"
    $OLEDBIN +b "Shutdown"
    sudo $OLEDBIN s
    sleep 5
    $OLEDBIN r
    sudo $OLEDBIN s
fi

# Shutdown
if [ $DEBUG = true ]; then
  echo "Shutdown"
fi
sync
sudo shutdown -h now
