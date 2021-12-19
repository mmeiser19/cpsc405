/*****************************************************************
*	entry.s
*	by Zhiyi Huang, hzy@cs.otago.ac.nz
*	University of Otago
*
********************************************************************/

.section .init, "ax"
.globl _start
_start:
	b boot_reset
	b boot_sleep	// undefined
	b boot_sleep	// svc
	b boot_sleep	// prefetch
	b boot_sleep	// abort
	b boot_sleep	// hypervisor
	b boot_sleep	// irq
	b boot_sleep	// fiq

	.balign 4
boot_sleep:
	wfe
	b boot_sleep

boot_reset:
	// Switch to SVC mode, all interrupts disabled
	.set PSR_MODE_SVC, 0x13
	.set PSR_MODE_IRQ_DISABLED, (1<<7)
	.set PSR_MODE_FIQ_DISABLED, (1<<6)
	msr	cpsr_c, #(PSR_MODE_SVC + PSR_MODE_FIQ_DISABLED + PSR_MODE_IRQ_DISABLED)

	// Disable caches, MMU, and flow prediction
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #(0x1 << 12)	// Disable instruction cache
	bic	r0, r0, #(0x1 << 11)	// Disable flow prediction
	bic	r0, r0, #(0x1 <<  2)	// Disable data cache
	bic	r0, r0, #0x1			// Disable MMU
	mcr	p15, 0, r0, c1, c0, 0

	// Enable ACTLR.SMP bit
	mrc	p15, 0, r0, c1, c0, 1
	orr	r0, r0, #(1 << 6)
	mcr	p15, 0, r0, c1, c0, 1

	// Invalidate TLB and branch prediction caches.
	mov	r0,#0
	mcr	p15, 0, r0, c8, c7, 0	// Invalidate unified TLB
	mcr	p15, 0, r0, c7, c5, 6	// Invalidate BPIALL

	// Update ARM vector address (early binding for debug)
	ldr	r0, =_start
	mcr	p15, 0, r0, c12, c0, 0	// VBAR

	// Cache invalidation for older Cortex-A
	// Note: Cortex-A7 (RPI2) does not need this part.
	// Invalidate l1 instruction cache
	mrc p15, 1, r0, c0, c0, 1
	tst r0, #0x3
	mov r0, #0
	mcrne p15, 0, r0, c7, c5, 0

	// Invalidate data/unified caches
	mrc p15, 1, r0, c0, c0, 1
	ands r3, r0, #0x07000000
	mov r3, r3, lsr #23
	beq finished

	mov r10, #0
loop1:
	add r2, r10, r10, lsr #1
	mov r1, r0, lsr r2
	and r1, r1, #7
	cmp r1, #2
	blt skip

	mcr p15, 2, r10, c0, c0, 0
	isb
	mrc p15, 1, r1, c0, c0, 0
	and r2, r1, #7
	add r2, r2, #4
	ldr r4, =0x3ff
	ands r4, r4, r1, lsr #3
	clz r5, r4
	ldr r7, =0x7fff
	ands r7, r7, r1, lsr #13
loop2:
	mov r9, r4

loop3:
	orr r11, r10, r9, lsl r5
	orr r11, r11, r7, lsl r2
	mcr p15, 0, r11, c7, c6,2
	subs r9, r9, #1
	bge loop3
	subs r7, r7, #1
	bge loop2

skip:
	add r10, r10, #2
	cmp r3, r10
	bgt loop1
finished:

	// MMU configurations
	// Activate TTBR0 by TTBCR reg
	// Translation Table Base Register
	// See for TTBCR format: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0433c/CIHFDBEJ.html
	// PD1 (Bit 5) - 0 perform translation table walk on TLB miss for TTBR1
	//             - 1 do not perform walk
	// PD0 (Bit 4) - 0 perform translation table walk on TLB miss tof TTBR0
	//             - 1 do not perform walk
	// N (Bits 0-2)- Boundary size of TTBR0 
	//             - b000=16KB, b001=8KB, b010=4KB, b011=2KB, b100=1KB, b101=512, b110=256, b111=128
	//   if N is set to 0, always use TTBR0
	//   if N is > 0 and bits [31:32-N] of VA are all 0's, use TTBR0, otherwise use TTBR1
	mov	r0,#0x0
	mcr	p15, 0, r0, c2, c0, 2

	// Set master translation table address (TTBR0)
	// See for TTBR format: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0433c/CIHFDBEJ.html
	// Translation Table Base (Bits 14-31) - base address of the translation table
	//  3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
	//  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// |  translation table base address   |             | |r|RGN|r|S| |
	// |               0                   |      0      |1|0|0 1|0|0|0|
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	//                                                    +-IRGN[0]   +-IRGN[1]
	// RGN (Bits 3-4) - Outer cacheable attributes for translation table walking
	//    - b00=Outer not-cahcheable
	//    - b01=Outer cacheable Write-back cached, Write-allocate
	//    - b10=Outer cacheable Write-through, no allocate on write
	//    - b11=Outer cacheable Write-back, no allcoate on write
	// IRGN[0] (Bit 6), IRGN[1] (Bit 0)
	// IRGN[1:0] - Indicates inner cacheability for translation table walk
	//    - b00=non-cacheable
	//    - b01=Write-back, Write-allocate
	//    - b10=Write-through, no allocate on write
	//    - b11=Write-back, no allocate on write
	// PHYSTART = 0x00000000  # defined in Makefile
	// K_PDX_BASE = PHYSTART + 0x4000
	// TBR0 gets 0x4048 - base address 0x4000, outer and inner write-back
	// r0 sets base address of master translation table to 0x4000
	ldr	r0,=K_PDX_BASE
	// r1 sets RGN to b01 - outer write-back cached
	mov	r1, #0x08
	// r1 sets IRGN to b01 - inner write-back cached
	orr	r1,r1,#0x40
	orr	r0,r0,r1
	mcr	p15, 0, r0, c2, c0, 0

	// Set depricated ARM domains
	// Domain Access Control Register (DACR)
	// See for DACR format: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0433c/CIHFDBEJ.html
	// DACR defines 16 domains, D0 (bits 0-1), D1 (bits 2-3), D2 (bits 4-5), and so on
	// D<n> - b00=not access, gens a domain fault 
	//      - b01=client, accesses checked against perm bits in TLB entry
	//      - b10=reserved, gens a domain fault
	//      - b11=manager, accesses not checked against perm bits in TLB entry
	// 0x55555555 sets 16 domains as clients
	mrc	p15, 0, r0, c3, c0, 0
	ldr	r0, =0x55555555
	mcr	p15, 0, r0, c3, c0, 0

	// Set all CPUs to wait except the primary CPU
	mrc p15, 0, r0, c0, c0, 5
	ands r0, r0, #0x03
	wfene
	bne mp_continue

	// MMU Phase 1
	// Create master translation table (page directory index)
mmu_phase1:

	ldr	r0,=K_PDX_BASE
	ldr	r1,=0xfff
	ldr	r2,=0

pagetable_invalidate:
	str	r2, [r0, r1, lsl#2]
	subs r1, r1, #1
	bpl	pagetable_invalidate

	// See file ARMmmu.pdf in same folder as entry.S for outstanding description of Paging
	//
	// ARM VA has two foramats: 12-20 and 12-8-12 bit attributes
	// For 12-20, we have
	//  12 bits are index into first level page table
	//  20 bits are offset into a 1MB section
	// For 12-8-12, we have
	//  12 bits are index into first level page table
	//  8 bits are index into second level page table
	//  12 bits index into a 4K page
	//
	// Page table attribute for first level descriptors
	// At this point, we create a level 1 page table that addresses 1MB sections
	// Bits 0-1 determine if one level section or two level pages
	// See Below
	// At this point, we create a one-level page table, which is a section page table.
	// We do not  perform two levels of address translation. Two levels is a traditional page table.
	// This first level page table only perform one level of address translations.
	// 0x14406= 0b0010 100 01 0 0000 0 01 10
	// 0x14c06= 0b0010 100 11 0 0000 0 01 10
	// 0x15c06= 0b0010 101 11 0 0000 0 01 10
	//            ZGSA-TEX-AP-I-DOMN-X-CB-10
	// See for defn: https://developer.arm.com/docs/ddi0333/latest/memory-management-unit/hardware-page-table-translation/armv6-page-table-translation-subpage-ap-bits-disabled
	// For first level page tables with Sections, section attributes in bits 0-18
	// Upper 12 bits of PA (ie page num) are in bits 20-31
	//  3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
	//  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// |  Section Base Addr    | |Z|G S|A|T E X|A P|I|D O M N|X|C|B|1 0|
	// |                       | |0|0|1|0|1 0 0|0 1|0|0 0 0 0|0|0|1|1 0|
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// Bits 0-1: 
	//    - 00 generates a Section Translation Fault
	//    - 01 indicates this is a Page Descriptor
	//    - 10 indicates this is a Section Descriptor (1MB section or 16MB supersection) - selected by bit 18.
	//    - 11 reserved for future use
	// Section Descriptor
	// Bits 2-3: C (bit 3) and B (bit 2)
	//    - C - Cahceable - indicates data placed in cache (if cache enabled)
	//    - B - Bufferable - indcates data written through write buffer (if write buffer enabled)
	// Bit 4: Should be 1 for backward compatibility
	// Bit 4: XN - 0 executable, 1 not-executable
	// Bits 5-8: Specify one of the sixteen domains held in Domain Access Control Register
	// Bit 9: What is bit 9?
	// Bits 10-11: Access permissions for this section.
	//    AP S R Permissions Permissions Notes
	//           Supervisor  User
	//    00 0 0 No Access   No Acccess  Access gens permission fault
	//    00 1 0 Read Only   No Access   Supervisor read only permitted
	//    00 0 1 Read Only   Read Only   Any write gnerates a permission fault
	//    00 1 1 Reserved
	//    10 x x Read/Write  No Access   Access allowed only in Supervisor mode
	//    10 x x Read/Write  Read Only   Writes in User mode cause permission fault
	//    11 x x Read/Write  Read/Write  Write in User mode cause permission fault
	//    xx 1 1 Reserved
	// Bit 18: Z - 0 is 1MB section, 1 is 16MB supersection
	// Bits 12-19: Written as 0 - Words from ARMmmu.pdf
	// Bit 17: nG - 0 global translation, 1 process-specific in TLB.
	// Bit 16: S - Shared bit - 0 non-shared, 1 shared memory
	// Bit 15: APX - extra access permission bit
	// Bits 12-14: TEX - What are TEX bits
	// Bits 20-32: Physical address if 1MB section
	//
	// For first level page tables with Pages, we have two level page access.
	// First access level 1 page Page Table Base Addres.
	// Then access Page Table to find entry.
	// Page table attributes in bits 0-8 of Page Table
	// Upper 22 bits of PA (ie page num) are in bits 20-31
	//  3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
	//  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// |        Page Table Base Address            | |D O M N|X| | |0 1|
	// |                                           | |0 0 0 0|0|0|0|0 1|
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// Bits 0-1: 
	//    - 00 generates a Section Translation Fault
	//    - 01 indicates this is a Page Descriptor
	//    - 10 indicates this is a Section Descriptor (1MB section or 16MB supersection) - selected by bit 18.
	//    - 11 reserved for future use
	// Bits 2-3:
	//    - 00 must be 00 for Page Table Descriptor
	// Bit 4: Should be 1 for backward compatibility
	// Bits 5-8: Specify one of the sixteen domains held in Domain Access Control Register
	// Bit 9: What is bit 9?
	// 
	// Page table attribute for second level descirptors - small page 4KB
	// ?????
	//  3 3 2 2 2 2 2 2 2 2 2 2 1 1 1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0
	//  1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	// |         page table base address       |G|S|A|T E X|A P|C|B|1 X|
	// |                                       |0|1|0|0|0|0|0|0|0|1|1|0|
	// +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
	//

	//ldr	r2,=0x14c06		//Inner cache
	//ldr	r2,=0x15c06 	//Outer cache
	ldr	r2,=0x14406

	// Map __pa_init_start to __pa_init_start address
	// r0 has address of page directory index or master translation table (K_PDX_BASE=0x4000)
	// page diretory index has 4096 entries, each addresses 1MB pages (total of 4GB)
	// We create two page entries in the page directory index
	// 1. One for VA 0x000000-0x100000 - Kernel assembly executes using these addresses
	// 2. One for VA 0x80000000-0x801000000 - Kernel C code executes using these addresses
	// Map VA 0x0000000-0x100000 (first MB) to PA 0x000000-0x100000
	ldr	r1,=PHYSTART
	lsr	r1, #20
	orr	r3, r2, r1, lsl#20
	str	r3, [r0, r1, lsl#2]

	// Map __va_kernel_start to __pa_init_start address
	// r0 has address of page directory index or master translation table (K_PDX_BASE=0x4000)
	// Map VA 0x800000000-0x80100000 (first MB) to PA 0x000000-0x100000
	ldr	r1,=PHYSTART
	lsr	r1, #20
	orr	r3, r2, r1, lsl#20
	ldr	r1,=KERNBASE
	lsr	r1, #20
	str	r3, [r0, r1, lsl#2]

	// Map device MMIO (just GPIO for LED debug)
	ldr	r2,=0xc16	//device template
	ldr	r1,=(MMIO_PA+0x200000)
	lsr	r1, #20
	orr	r3, r2, r1, lsl#20
	ldr	r1,=(MMIO_VA+0x200000)
	lsr	r1, #20
	str	r3, [r0, r1, lsl#2]

	// All processors will start from here after waiting:
mp_continue:
	ldr sp, =(KERNBASE+0x3000)
	// Enable I/D$, MMU, and flow prediction.
	dsb
	ldr r1,=_pagingstart
	mrc	p15, 0, r0, c1, c0, 0
	orr r0, r0,	#(0x1 << 13)		// High vector
	//orr	r0, r0, #(0x1 << 12)	// Enable I$
	//orr	r0, r0, #(0x1 << 11)	// Enable flow prediction
	//orr	r0, r0, #(0x1 <<  2)	// Enable D$
	orr	r0, r0, #0x1				// Enable MMU
	mcr	p15, 0, r0, c1, c0, 0
	bx r1

	.section .text
.global _pagingstart
_pagingstart:
	bl cmain  /* call C functions now */
	bl NotOkLoop

.global acknowledge
acknowledge:
	//Turn on the LED
	ldr r2,=MMIO_VA
	add r2,r2,#0x200000
	//Function select
	mov r3,#1

	#ifdef RPI1
	lsl r3,#18			//Pi1 ACT LED: GPIO#16 (GPFSEL1)
	str r3,[r2,#0x4]
	mov r3,#1
	lsl r3,#16
	str r3,[r2,#0x28]	//Pi1 (GPCLR0)
	#endif

	#ifdef RPI2
	lsl r3,#21			//Pi2 ACT LED: GPIO#47 (GPFSEL4)
	str r3,[r2,#0x10]
	mov r3,#1
	lsl r3,#15
	str r3,[r2,#0x20] //Pi2 (GPSET1)
	#endif

	bx lr

.global dsb_barrier
dsb_barrier:
	#ifdef RPI1
	mov r0, #0
	mcr p15, 0, r0, c7, c10, 4
	#else
	dsb
	isb
	#endif
	bx lr
.global flush_dcache_all
flush_dcache_all:
	#ifdef RPI1
	mov r0, #0
	mcr p15, 0, r0, c7, c10, 4 /* dsb */
	mov r0, #0
	mcr p15, 0, r0, c7, c14, 0 /* invalidate d-cache */
	#else
	dsb
	isb
	#endif
	bx lr
.global flush_idcache
flush_idcache:
	#ifdef RPI1
	mov r0, #0
	mcr p15, 0, r0, c7, c10, 4 /* dsb */
	mov r0, #0
	mcr p15, 0, r0, c7, c14, 0 /* invalidate d-cache */
	mov r0, #0
	mcr p15, 0, r0, c7, c5, 0 /* invalidate i-cache */
	#else
	dsb
	isb
	#endif
	bx lr
.global flush_tlb
flush_tlb:
	#ifdef RPI1
	mov r0, #0
	mcr p15, 0, r0, c8, c7, 0
	mcr p15, 0, r0, c7, c10, 4
	#else
	dsb
	isb
	mov	r0,#0
	mcr	p15, 0, r0, c8, c7, 0	// Invalidate unified TLB
	mcr	p15, 0, r0, c7, c5, 6	// Invalidate BPIALL
	dsb
	isb
	#endif
	bx lr
.global flush_dcache /* flush a range of data cache flush_dcache(va1, va2) */
flush_dcache:
	#ifdef RPI1
	mcrr p15, 0, r0, r1, c14
	#else
	dsb
	isb
	#endif
	bx lr

.global set_pgtbase /* set the page table base set_pgtbase(base) */
set_pgtbase:
	mcr p15, 0, r0, c2, c0
	bx lr

.global getsystemtime
getsystemtime:
	ldr r0, =(MMIO_VA+0x003004) /* addr of the time-stamp lower 32 bits */
	ldrd r0, r1, [r0]
	bx lr

.section .data

.align 4
.globl font
font:
	.incbin "font1.bin"

.align 4
.global _binary_initcode_start
_binary_initcode_start:
	.incbin "initcode"
.global _binary_initcode_end
_binary_initcode_end:

.align 4
.global _binary_fs_img_start
_binary_fs_img_start:
        .incbin "fs.img"
.global _binary_fs_img_end
_binary_fs_img_end:
