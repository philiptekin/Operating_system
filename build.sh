#!/bin/bash

set -e  # Exit immediately if any command fails

# Step 1: Compile kernel.c to kernel.o
echo "[*] Compiling kernel.c..."
i686-elf-gcc -c kernel.c -o kernel.o -std=gnu99 -ffreestanding -O2 -Wall -Wextra

# Step 2: Link kernel.o and boot.o into myos.bin
echo "[*] Linking kernel and bootloader..."
i686-elf-gcc -T linker.ld -o myos.bin -ffreestanding -O2 -nostdlib boot.o kernel.o -lgcc

# Step 3: Copy the binary to the ISO directory
echo "[*] Copying kernel to ISO directory..."
cp myos.bin isodir/boot/myos.bin

# Step 4: Create the ISO image using GRUB
echo "[*] Creating ISO with grub-mkrescue..."
grub-mkrescue -o myos.iso isodir

# Step 5: Run the OS in QEMU
echo "[*] Launching OS in QEMU..."
qemu-system-i386 -kernel myos.bin