global long_mode_start

section .text
bits 64
long_mode_start:
    ; print banner to screen
    ; rather shameful assembly here,
    ; but oh well, this is it for now
    mov rax, [banner]
    mov qword [0xb8000], rax
    mov rax, [banner + 8]
    mov qword [0xb8008], rax
    mov rax, [banner + 16]
    mov qword [0xb8010], rax
    hlt

section .rodata:
banner:
    dq 0x2f752f6e2f692f4d
    dq 0x2f382f782f202f78
    dq 0x2f342f362f5f2f36
.banner_length:
