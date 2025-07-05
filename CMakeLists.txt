cmake_minimum_required(VERSION 3.15)
project(myos C)

# Use your cross-compiler
set(CMAKE_C_COMPILER i686-elf-gcc)

# Output binary name
set(KERNEL_BIN myos.bin)

# Source files
set(KERNEL_SOURCES kernel.c)
set(BOOT_OBJ ${CMAKE_SOURCE_DIR}/boot.o)  # Full path to boot.o

# Compile kernel.c to kernel.o using OBJECT library
add_library(kernel_obj OBJECT ${KERNEL_SOURCES})

target_compile_options(kernel_obj PRIVATE
    -std=gnu99
    -ffreestanding
    -O2
    -Wall
    -Wextra
)

# Link kernel.o and boot.o into myos.bin using add_custom_command
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
    COMMAND ${CMAKE_C_COMPILER} -T ${CMAKE_SOURCE_DIR}/linker.ld
            -o ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
            -ffreestanding -O2 -nostdlib
            ${BOOT_OBJ} $<TARGET_OBJECTS:kernel_obj> -lgcc
    DEPENDS ${BOOT_OBJ} $<TARGET_OBJECTS:kernel_obj> ${CMAKE_SOURCE_DIR}/linker.ld
    COMMENT "Linking kernel and bootloader..."
)

add_custom_target(link_kernel ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN})

# Copy myos.bin to isodir/boot/myos.bin after linking
add_custom_command(
    TARGET link_kernel POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
            ${CMAKE_SOURCE_DIR}/isodir/boot/myos.bin
    COMMENT "Copying kernel to ISO directory..."
)

# Create ISO image
add_custom_command(
    TARGET link_kernel POST_BUILD
    COMMAND grub-mkrescue -o ${CMAKE_SOURCE_DIR}/myos.iso ${CMAKE_SOURCE_DIR}/isodir
    COMMENT "Creating ISO with grub-mkrescue..."
)

# Run OS in QEMU
add_custom_target(run
    COMMAND qemu-system-i386 -kernel ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
    COMMENT "Launching OS in QEMU..."
    DEPENDS link_kernel
)