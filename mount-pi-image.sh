#!/bin/bash

if [[ x"${1}" == x"" || x"${2}" == x"" ]]; then
  echo -e "\nUsage mount:\t$0 <image> <mountpoint>\nUsage umount:\t$0 -u <mountpoint>"
  exit 2
fi

IMAGE="$1"
MOUNTPOINT="`readlink -f $2`"

[[ "x`cat /proc/mounts | grep ${MOUNTPOINT}/be`" != "x" ]] && sudo umount -l "${MOUNTPOINT}/be"
[[ "x`cat /proc/mounts | grep ${MOUNTPOINT}/boot`" != "x" ]] && sudo umount -l "${MOUNTPOINT}/boot"
[[ "x`cat /proc/mounts | grep ${MOUNTPOINT}/dev/pts`" != "x" ]] && sudo umount -l "${MOUNTPOINT}/dev/pts"
[[ "x`cat /proc/mounts | grep ${MOUNTPOINT}/sys`" != "x" ]] && sudo umount -l "${MOUNTPOINT}/sys"
[[ "x`cat /proc/mounts | grep ${MOUNTPOINT}/proc`" != "x" ]] && sudo umount -l "${MOUNTPOINT}/proc"
[ -d "${MOUNTPOINT}/be" ] && sudo rmdir "${MOUNTPOINT}/be"
if [[ "x`cat /proc/mounts | grep ${MOUNTPOINT}`" != "x" ]]; then
  [ -e "${MOUNTPOINT}/etc/ld.so.preload" ] && sudo sed -i 's/^#//' "${MOUNTPOINT}/etc/ld.so.preload"
  sudo umount -l "${MOUNTPOINT}"
fi

if [ "${IMAGE}" != "-u" ]; then
  if [ -e "${IMAGE}" ]; then
    # Check for mountpoint
    if [ ! -d "${MOUNTPOINT}" ]; then
      echo -e "\nERROR: Mountpoint directory '${MOUNTPOINT}' does not exist."
      exit 1
    fi

    OFFSET_BOOT=`sfdisk -uS -l "${IMAGE}" 2>/dev/null | grep img1 | awk '{print $2}'`
    OFFSET_ROOT=`sfdisk -uS -l "${IMAGE}" 2>/dev/null | grep img2 | awk '{print $2}'`

    # Check if given Image file has two partition
    if [[ -z $OFFSET_ROOT || -z $OFFSET_BOOT ]]; then
      echo -e "\nERROR: File '${IMAGE}' does not seem to be a valid image file."
      exit 1
    fi

    sudo mount -o loop,offset=$((512*${OFFSET_ROOT})) "${IMAGE}" "${MOUNTPOINT}"
    sudo mount -o loop,offset=$((512*${OFFSET_BOOT})) "${IMAGE}" "${MOUNTPOINT}/boot"
    sudo mount -o bind /dev/pts "${MOUNTPOINT}/dev/pts"
    sudo mount -o bind /sys "${MOUNTPOINT}/sys"
    sudo mount -o bind /proc "${MOUNTPOINT}/proc"
    [ ! -d "${MOUNTPOINT}/be" ] && sudo mkdir -p "${MOUNTPOINT}/be"
    sudo mount -o bind "${MOUNTPOINT}/../" "${MOUNTPOINT}/be"

    sudo cp -f /usr/bin/qemu-arm-static "${MOUNTPOINT}/usr/bin/qemu-arm-static"
    [ -e "${MOUNTPOINT}/etc/ld.so.preload" ] && sudo sed -i 's/^/#/' "${MOUNTPOINT}/etc/ld.so.preload"
    sudo sh -c "echo \"export LC_ALL=C\" > \"${MOUNTPOINT}/etc/environment\""
    sudo sh -c "echo \"export LC_ALL=C\" >> "${MOUNTPOINT}/root/.bashrc""
    sudo sh -c "echo 'export PS1=\"(xMZ_Mod) \$PS1\"' >> \"${MOUNTPOINT}/root/.bashrc\""
    [ ! -e "${MOUNTPOINT}/etc/mtab" ] && sudo ln -s /proc/mounts "${MOUNTPOINT}/etc/mtab"
  else
    echo -e "\nERROR: Image file '${IMAGE}' not found."
    exit 1
  fi
else
  echo -e "\nImage was unmouted."
fi

exit 0

