#!/bin/sh

# User-controllable options
grub_modinfo_target_cpu=arm64
grub_modinfo_platform=efi
grub_disk_cache_stats=0
grub_boot_time_stats=0
grub_have_font_source=1

# Autodetected config
grub_have_asm_uscore=0
grub_i8086_addr32=""
grub_i8086_data32=""
grub_bss_start_symbol=""
grub_end_symbol=""

# Build environment
grub_target_cc='gcc-5'
grub_target_cc_version='gcc-5 (Ubuntu/Linaro 5.4.0-6ubuntu1~16.04.11) 5.4.0 20160609'
grub_target_cflags=' -Os -Wall -W -Wshadow -Wpointer-arith -Wundef -Wchar-subscripts -Wcomment -Wdeprecated-declarations -Wdisabled-optimization -Wdiv-by-zero -Wfloat-equal -Wformat-extra-args -Wformat-security -Wformat-y2k -Wimplicit -Wimplicit-function-declaration -Wimplicit-int -Wmain -Wmissing-braces -Wmissing-format-attribute -Wmultichar -Wparentheses -Wreturn-type -Wsequence-point -Wshadow -Wsign-compare -Wswitch -Wtrigraphs -Wunknown-pragmas -Wunused -Wunused-function -Wunused-label -Wunused-parameter -Wunused-value  -Wunused-variable -Wwrite-strings -Wnested-externs -Wstrict-prototypes -g -Wredundant-decls -Wmissing-prototypes -Wmissing-declarations -Wcast-align  -Wextra -Wattributes -Wendif-labels -Winit-self -Wint-to-pointer-cast -Winvalid-pch -Wmissing-field-initializers -Wnonnull -Woverflow -Wvla -Wpointer-to-int-cast -Wstrict-aliasing -Wvariadic-macros -Wvolatile-register-var -Wpointer-sign -Wmissing-prototypes -Wmissing-declarations -Wformat=2 -freg-struct-return -fno-dwarf2-cfi-asm -fno-asynchronous-unwind-tables -Qn -mpc-relative-literal-loads -fno-stack-protector -Wtrampolines -Werror'
grub_target_cppflags='-Wno-unused-but-set-variable -Wall -W -I$(top_srcdir)/include -I$(top_builddir)/include  -DGRUB_MACHINE_EFI=1 -DGRUB_MACHINE=ARM64_EFI -nostdinc -isystem /usr/lib/gcc/aarch64-linux-gnu/5/include'
grub_target_ccasflags=' -g'
grub_target_ldflags=' -Wl,--build-id=none'
grub_target_strip='strip'
grub_target_nm='nm'
grub_target_ranlib='ranlib'
grub_target_objconf=''
grub_target_obj2elf=''

# Version
grub_version="2.02~beta2"
grub_package="grub"
grub_package_string="GRUB 2.02~beta2-36ubuntu3.19"
grub_package_version="2.02~beta2-36ubuntu3.19"
grub_package_name="GRUB"
grub_package_bugreport="bug-grub@gnu.org"
