global start
extern long_mode_start

section .rodata
gdt64:
    dq 0 ; zero entry
.code: equ $ - gdt64
    ; code segment
    dq (1 << 44) | (1 << 47) | (1 << 41) | (1 << 43) | (1 << 53)
.data: equ $ - gdt64
    ; data segment
    dq (1 << 44) | (1 << 47) | (1 << 41)
.pointer:
    dw $ - gdt64 - 1
    dq gdt64

section .text
bits 32
start:
    mov esp, stack_top

    call check_multiboot
    call check_cpuid
    call check_long_mode

    call set_up_page_tables
    call enable_paging

    ; load the 64-bit GDT
    lgdt [gdt64.pointer]

    ; update selectors
    mov ax, gdt64.data
    mov ss, ax  ; stack selector
    mov ds, ax  ; data selector
    mov es, ax  ; extra selector

    ; jump far extern long_mode_start
    ; this sets the new code selector for 64-bit long mode
    ; so that long_mode_start will be 64-bit code
    jmp gdt64.code:long_mode_start

error:
    mov dword [0xb8000], 0x4f524f45
    mov dword [0xb8004], 0x4f3a4f52
    mov dword [0xb8008], 0x4f204f20
    mov byte  [0xb800a], al
    hlt

check_multiboot:
    cmp eax, 0x36d76289
    jne .no_multiboot
    ret
.no_multiboot:
    mov al, "0"
    jmp error

check_cpuid:
    ; Check if CPUID is supported by attempting to flip the ID bit (bit 21) in
    ; the FLAGS register. If we can flip it, CPUID is available.

    ; Copy FLAGS in to EAX via stack
    pushfd
    pop eax

    ; Copy to ECX as well for comparing later on
    mov ecx, eax

    ; Flip the ID bit
    xor eax, 1 << 21

    ; Copy EAX to FLAGS via the stack
    push eax
    popfd

    ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
    pushfd
    pop eax

    ; Restore FLAGS from the old version stored in ECX (i.e. flipping the ID bit
    ; back if it was ever flipped).
    push ecx
    popfd

    ; Compare EAX and ECX. If they are equal then that means the bit wasn't
    ; flipped, and CPUID isn't supported
    xor eax, ecx
    jz .no_cpuid
    ret
.no_cpuid:
    mov al, "1"
    jmp error

check_long_mode:
    mov eax, 0x80000000  ; Set the A-register to 0x80000000.
    cpuid                ; CPU identification.
    cmp eax, 0x80000001  ; Compare the A-register with 0x80000001.
    jb .no_long_mode     ; It is less, there is no long mode.
    mov eax, 0x80000001  ; Set the A-register to 0x80000001.
    cpuid                ; CPU identification.
    test edx, 1 << 29    ; Test if the LM-bit is set in the D-register.
    jz .no_long_mode     ; They aren't, there is no long mode.
    ret
.no_long_mode:
    mov al, "2"
    jmp error

set_up_page_tables:
    ; map first P4 entry to P3 table
    mov eax, p3_table
    or eax, 0b11        ; present + writable
    mov [p4_table], eax

    ; map first P3 entry to P2 table
    mov eax, p2_table
    or eax, 0b11
    mov [p3_table], eax

    ; map each P2 entry to a huge 2MB page
    mov ecx, 0

.map_p2_table:
    ; map ecx-th P2 entry to a huge page that starts @ 2MB*ecx
    mov eax, 0x200000   ; 2 MB
    mul ecx             ; start address of ecx-th page
    or eax, 0b10000011  ; present + writable + huge
    mov [p2_table + ecx * 8], eax ; map ecx-th entry
    inc ecx             ; increase counter
    cmp ecx, 512        ; if counter == 512 the whole P2 is mapped
    jne .map_p2_table

    ret

enable_paging:
    ; load P4 into cr3 register (used by CPU to access the P4 table)
    mov eax, p4_table
    mov cr3, eax

    ; enable PAE-flag in cr4 (Physical Address Extension)
    mov eax, cr4
    or eax, 1 << 5
    mov cr4, eax

    ; set the long mode bit in the EFER MSR (model specific register)
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 << 8
    wrmsr

    ; enable paging in the cr0 register
    mov eax, cr0
    or eax, 1 << 31
    mov cr0, eax

    ret

section .bss
# 2 MB pages: P4 huge 0, P3 huge 0, P2 huge 1, P1 huge 0 (p1 not needed)
align 4096
p4_table:
    resb 4096
p3_table:
    resb 4096
p2_table:
    resb 4096
stack_bottom:
    resb 64
stack_top:
