#include "linux_config.h"

.arm
.align 4
.code 32
.text

@ LCD Frambuffers stuff (Physical Addresses)
#define LCD_FB_PDC0           (0x10400400)
#define LCD_FB_PDC1           (0x10400500)
#define LCD_FB_A_ADDR_OFFSET  (0x68)
#define LCD_FB_B_ADDR_OFFSET  (0x94)
#define FB_TOP_SIZE           (400*240*3)
#define FB_BOT_SIZE           (320*240*3)
#define FB_TOP_LEFT1          (FB_BASE_PA)
#define FB_TOP_LEFT2          (FB_TOP_LEFT1  + FB_TOP_SIZE)
#define FB_TOP_RIGHT1         (FB_TOP_LEFT2  + FB_TOP_SIZE)
#define FB_TOP_RIGHT2         (FB_TOP_RIGHT1 + FB_TOP_SIZE)
#define FB_BOT_1              (FB_TOP_RIGHT2 + FB_TOP_SIZE)
#define FB_BOT_2              (FB_BOT_1      + FB_BOT_SIZE)

@ This must be Position-independent Code

	.global linux_payloads_start
linux_payloads_start:

	.cpu arm946e-s

arm9_start:
	b arm9_init
	@ required by BRAHMA
	arm9ep_backup:  .long 0xFFFF0000
arm9_init:
	b linux_arm9_stage_start

@@@@@@@@@@@@@@@@@@@@@@@@ ARM9 Stage 0 @@@@@@@@@@@@@@@@@@@@@@@@

linux_arm9_stage_start:

	@ Disable MPU
	mrc p15, 0, r0, c1, c0, 0
	bic r0, r0, #1
	mcr p15, 0, r0, c1, c0, 0

	@ Disable IRQ and FIQ
	mrs r0, cpsr
	orr r0, r0, #(0x80 | 0x40)
	msr cpsr_c, r0

	@ The ARM9 code is loaded to 0x23F00000 so the
	@ linux_arm11_stage_start address will be at:
	@     0x23F00000 + ARM9_payload_size

	ldr r0, =PA_ARM11_CODE_ADDR
	ldr r1, linux_arm11_stage_pa
	str r1, [r0]

loop:
	@ Enter wait-for-interrupt state
	mov r0, #0
	mcr p15, 0, r0, c7, c0, 4
	b loop

	.ltorg

linux_arm11_stage_pa:
	.long 0x23F00000 + (linux_arm11_stage_start - linux_payloads_start)


@@@@@@@@@@@@@@@@@@@@@@@@ ARM11 Stage 1 @@@@@@@@@@@@@@@@@@@@@@@@

	.cpu mpcore
linux_arm11_stage_start:

	@ Disable FIQs, IRQs, imprecise aborts
	@ and enter SVC mode
	CPSID aif, #0x13

	@ Invalidate Entire Instruction Cache,
	@ also flushes the branch target cache
	mov r0, #0
	mcr p15, 0, r0, c7, c5, 0

	@ Invalidate Entire Data Cache
	mov r0, #0
	mcr p15, 0, r0, c7, c6, 0

	@ Disable the MMU and data cache
	@ (the MMU is already disabled)
	mrc p15, 0, r1, c1, c0, 0
	bic r1, r1, #0b101
	mcr p15, 0, r1, c1, c0, 0

	@ Clear exclusive records
	clrex

	@@@ Map Framebuffers @@@

	@ Top screen
	ldr r0, =LCD_FB_PDC0

	@ Left eye
	ldr r1, =FB_TOP_LEFT1
	str r1, [r0, #(LCD_FB_A_ADDR_OFFSET + 0)]
	ldr r1, =FB_TOP_LEFT2
	str r1, [r0, #(LCD_FB_A_ADDR_OFFSET + 4)]

	@ Right eye
	ldr r1, =FB_TOP_RIGHT1
	str r1, [r0, #(LCD_FB_B_ADDR_OFFSET + 0)]
	ldr r1, =FB_TOP_RIGHT2
	str r1, [r0, #(LCD_FB_B_ADDR_OFFSET + 4)]

	@ Bottom screen
	ldr r0, =LCD_FB_PDC1

	ldr r1, =FB_BOT_1
	str r1, [r0, #(LCD_FB_A_ADDR_OFFSET + 0)]
	ldr r1, =FB_BOT_2
	str r1, [r0, #(LCD_FB_A_ADDR_OFFSET + 4)]

	@ Setup the registers before
	@ jumping to the kernel entry
	mov r0, #0
	ldr r1, =MACHINE_NUMBER
	ldr r2, =PARAMS_ADDR
	ldr lr, =ZIMAGE_ADDR

	@ Jump to the kernel!
	bx lr

	.ltorg

	.global linux_payloads_end
linux_payloads_end: