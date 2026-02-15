#!/bin/bash

# --- رنگ‌ها برای زیبایی خروجی ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting Mikrotik CHR Auto-Installer...${NC}"

# ۱. تشخیص خودکار شبکه
INTERFACE=$(ip route get 8.8.8.8 | awk '{print $5; exit}')
ADDRESS=$(ip addr show $INTERFACE | grep global | awk '{print $2}' | head -n 1)
GATEWAY=$(ip route list | grep default | awk '{print $3}')

# ۲. تشخیص هوشمند هارد اصلی
# این دستور هاردی که سیستم‌عامل فعلی روی آن است را پیدا می‌کند
DISK=$(lsblk -dpno NAME | grep -E 'sd|vd|nvme' | head -n 1)

echo -e "Network Interface: ${GREEN}$INTERFACE${NC}"
echo -e "IP Address: ${GREEN}$ADDRESS${NC}"
echo -e "Target Disk: ${RED}$DISK${NC}"

# ۳. دریافت اطلاعات از کاربر
echo "------------------------------------------"
read -p "Enter Mikrotik Username (default: admin): " USERNAME
USERNAME=${USERNAME:-admin}
read -s -p "Enter Mikrotik Password: " PASSWORD
echo -e "\n------------------------------------------"

# ۴. تایید نهایی برای جلوگیری از اشتباه
echo -e "${RED}WARNING: All data on $DISK will be ERASED!${NC}"
read -p "Do you want to proceed? (y/n): " CONFIRM
if [[ $confirm != [yY] ]]; then
    echo "Installation cancelled."
    exit 1
fi

# ۵. پیدا کردن آخرین نسخه Stable
echo "Fetching latest Mikrotik version..."
VERSIONCHR=$(wget -qO- https://download.mikrotik.com/routeros/LATEST.7.stable)
if [ -z "$VERSIONCHR" ]; then VERSIONCHR="7.14.3"; fi # Backup version

# ۶. دانلود و اکسترکت
echo "Downloading Mikrotik CHR $VERSIONCHR..."
wget -4 "https://download.mikrotik.com/routeros/$VERSIONCHR/chr-$VERSIONCHR.img.zip" -O chr.img.zip
apt update && apt install -y unzip coreutils
unzip -p chr.img.zip > chr.img

# ۷. تنظیمات خودکار (Autorun)
echo "Configuring Cloud Hosted Router..."
mkdir -p /mnt/mikrotik
mount -o loop,offset=33571840 chr.img /mnt/mikrotik
echo "/ip address add address=$ADDRESS interface=[/interface ethernet find where name=ether1]" > /mnt/mikrotik/rw/autorun.scr
echo "/ip route add gateway=$GATEWAY" >> /mnt/mikrotik/rw/autorun.scr
echo "/user set 0 name=$USERNAME password=$PASSWORD" >> /mnt/mikrotik/rw/autorun.scr
echo "/ip dns set server=8.8.8.8,1.1.1.1" >> /mnt/mikrotik/rw/autorun.scr
umount /mnt/mikrotik

# ۸. نوشتن روی دیسک و ریبوت
echo "Writing to disk... Please wait."
echo u > /proc/sysrq-trigger
dd if=chr.img bs=1024 of=$DISK
echo s > /proc/sysrq-trigger

echo -e "${GREEN}Installation Complete! Rebooting now...${NC}"
sleep 3
echo b > /proc/sysrq-trigger