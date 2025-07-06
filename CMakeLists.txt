cmake_minimum_required(VERSION 3.15)
project(myos C)

# Use your cross-compiler
set(CMAKE_C_COMPILER i686-elf-gcc)

# Use assembler for bootloader
set(CMAKE_ASM_COMPILER i686-elf-as)

# Compiler flags
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -ffreestanding -O2 -Wall -Wextra")

# Output binary name
set(KERNEL_BIN myos.kernel)

# Source files
set(SOURCES ${CMAKE_SOURCE_DIR}/kernel.c)

# Get built-in startup files from GCC
execute_process(
    COMMAND ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -print-file-name=crtbegin.o
    OUTPUT_VARIABLE CRTBEGIN_OBJ
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
    COMMAND ${CMAKE_C_COMPILER} ${CMAKE_C_FLAGS} -print-file-name=crtend.o
    OUTPUT_VARIABLE CRTEND_OBJ
    OUTPUT_STRIP_TRAILING_WHITESPACE
)

# --- Compile crti.s and crtn.s into crti.o and crtn.o ---
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/crti.o
    COMMAND ${CMAKE_ASM_COMPILER} -c ${CMAKE_SOURCE_DIR}/crti.s -o ${CMAKE_BINARY_DIR}/crti.o
    DEPENDS ${CMAKE_SOURCE_DIR}/crti.s
    COMMENT "Compiling crti.s"
)

add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/crtn.o
    COMMAND ${CMAKE_ASM_COMPILER} -c ${CMAKE_SOURCE_DIR}/crtn.s -o ${CMAKE_BINARY_DIR}/crtn.o
    DEPENDS ${CMAKE_SOURCE_DIR}/crtn.s
    COMMENT "Compiling crtn.s"
)

# Compile boot.s to boot.o using OBJECT library
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/boot.o
    COMMAND ${CMAKE_ASM_COMPILER} ${CMAKE_SOURCE_DIR}/boot.s -o ${CMAKE_BINARY_DIR}/boot.o
    DEPENDS ${CMAKE_SOURCE_DIR}/boot.s
    COMMENT "Compiling multiboot header..."
)

add_custom_target(startup_objs
    DEPENDS ${CMAKE_BINARY_DIR}/crti.o ${CMAKE_BINARY_DIR}/crtn.o ${CMAKE_BINARY_DIR}/boot.o
)

# Startup files (assumed in the source directory)
set(CRTI_OBJ ${CMAKE_BINARY_DIR}/crti.o)
set(CRTN_OBJ ${CMAKE_BINARY_DIR}/crtn.o)

add_library(kernel_obj OBJECT ${SOURCES})

target_compile_options(kernel_obj PRIVATE
    -std=gnu99
    -ffreestanding
    -O2
    -Wall
    -Wextra
)

# Later in your link step (example):
add_custom_command(
    OUTPUT myos.kernel
    COMMAND ${CMAKE_C_COMPILER} -T ${CMAKE_SOURCE_DIR}/linker.ld -o myos.kernel
            -ffreestanding -O2 -nostdlib
            ${CRTI_OBJ} 
            ${CRTBEGIN_OBJ} 
            ${CMAKE_BINARY_DIR}/boot.o
            $<TARGET_OBJECTS:kernel_obj>
            ${CRTEND_OBJ}
            ${CRTN_OBJ}
            
            -lgcc
    DEPENDS kernel_obj startup_objs
    COMMENT "Linking myos.kernel..."
)

add_custom_target(link_kernel ALL DEPENDS myos.kernel)

# Copy myos.kernel to isodir/boot/myos.kernel after linking
add_custom_command(
    TARGET link_kernel POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
            ${CMAKE_SOURCE_DIR}/isodir/boot/myos.kernel
    COMMENT "Copying kernel to ISO directory..."
)

# Copy grub.cfg to isodir/boot/grub/grub.cfg
add_custom_command(
    TARGET link_kernel POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_SOURCE_DIR}/grub.cfg
            ${CMAKE_SOURCE_DIR}/isodir/boot/grub/grub.cfg
    COMMENT "Copying grub configuration..."
)

# Create ISO image
add_custom_command(
    TARGET link_kernel POST_BUILD
    COMMAND grub-mkrescue -o ${CMAKE_CURRENT_BINARY_DIR}/myos.iso ${CMAKE_SOURCE_DIR}/isodir
    COMMENT "Creating ISO with grub-mkrescue..."
)

# Run OS in QEMU
add_custom_target(run
    COMMAND qemu-system-i386 -kernel ${CMAKE_CURRENT_BINARY_DIR}/${KERNEL_BIN}
    COMMENT "Launching OS in QEMU..."
    DEPENDS link_kernel
)

set(INTERNAL_OBJS
  ${CRTI_OBJ}
  ${CRTN_OBJ}
  ${CMAKE_BINARY_DIR}/boot.o
  ${CMAKE_BINARY_DIR}/bar.o
  ${CMAKE_BINARY_DIR}/crtn.o
  ${CMAKE_BINARY_DIR}/myos.iso
)

# Clean target for intermediate files
add_custom_target(clean_kernel
    COMMAND ${CMAKE_COMMAND} -E rm -f ${KERNEL_BIN} ${INTERNAL_OBJS}
    COMMAND ${CMAKE_COMMAND} -E rm -rf ${CMAKE_SOURCE_DIR}/isodir
    COMMAND ${CMAKE_COMMAND} -E rm -f myos.kernel $(INTERNAL_OBJECTS)
    COMMENT "Cleaning kernel build..."
)