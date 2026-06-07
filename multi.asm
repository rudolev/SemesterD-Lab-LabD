global main
extern printf, fgets, malloc, stdin, putchar

section .data
x_struct:   db 5
x_num:      db 0xaa, 1, 2, 0x44, 0x4f

y_struct:   db 6
y_num:      db 0xaa, 1, 2, 3, 0x44, 0x4f

STATE:  dw  0xACE1
MASK:   dw  0xB400

fmt_byte:   db  "%02hhx", 0
fmt_nl:     db  10, 0

section .bss
BUFSIZE     equ 512
inputbuf:   resb BUFSIZE

section .text

hex_char_to_nibble:
    cmp al, '9'
    jle .digit
    or  al, 0x20
    sub al, 'a'-10
    ret
.digit:
    sub al, '0'
    ret

print_multi:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi

    mov     esi, [ebp+8]
    movzx   ecx, byte [esi]
    lea     ebx, [esi+1]

    mov     eax, ecx
    dec     eax
.pm_skip:
    cmp     eax, 0
    jle     .pm_print
    cmp     byte [ebx+eax], 0
    jne     .pm_print
    dec     eax
    jmp     .pm_skip

.pm_print:
    mov     ecx, eax
.pm_loop:
    movzx   eax, byte [ebx+ecx]
    push    ecx
    push    eax
    push    fmt_byte
    call    printf
    add     esp, 8
    pop     ecx
    dec     ecx
    jns     .pm_loop
    push    fmt_nl
    call    printf
    add     esp, 4
    pop     esi
    pop     ebx
    pop     ebp
    ret

getmulti_impl:
    push    ebp
    mov     ebp, esp
    sub     esp, 8
    push    ebx
    push    esi
    push    edi
    push    dword [stdin]
    push    BUFSIZE
    push    inputbuf
    call    fgets
    add     esp, 12
    test    eax, eax
    jz      .gm_err

    mov     esi, inputbuf
    xor     ecx, ecx
.gm_cnt:
    movzx   eax, byte [esi+ecx]
    cmp     al, 10
    je      .gm_cnt_done
    cmp     al, 13
    je      .gm_cnt_done
    cmp     al, 0
    je      .gm_cnt_done
    inc     ecx
    jmp     .gm_cnt
.gm_cnt_done:
    mov     [ebp-4], ecx
    mov     eax, ecx
    inc     eax
    shr     eax, 1
    test    eax, eax
    jz      .gm_err
    mov     [ebp-8], eax

    lea     eax, [eax+1]
    push    eax
    call    malloc
    add     esp, 4
    test    eax, eax
    jz      .gm_err
    mov     ebx, eax

    mov     ecx, [ebp-8]
    mov     [ebx], cl

    mov     edi, [ebp-8]
    dec     edi
    mov     ecx, [ebp-4]

    test    ecx, 1
    jz      .gm_pairs
    movzx   eax, byte [esi]
    inc     esi
    dec     ecx
    call    hex_char_to_nibble
    mov     [ebx+1+edi], al
    dec     edi

.gm_pairs:
    cmp     ecx, 0
    jle     .gm_done
    movzx   eax, byte [esi]
    inc     esi
    push    ebx
    call    hex_char_to_nibble
    shl     al, 4
    mov     dl, al
    pop     ebx
    movzx   eax, byte [esi]
    inc     esi
    push    ebx
    call    hex_char_to_nibble
    or      al, dl
    mov     [ebx+1+edi], al
    dec     edi
    pop     ebx
    sub     ecx, 2
    jmp     .gm_pairs

.gm_done:
    mov     eax, ebx
    jmp     .gm_ret
.gm_err:
    xor     eax, eax
.gm_ret:
    pop     edi
    pop     esi
    pop     ebx
    add     esp, 8
    pop     ebp
    ret

get_maxmin:
    movzx   ecx, byte [eax]
    movzx   edx, byte [ebx]
    cmp     ecx, edx
    jge     .already_ordered
    xchg    eax, ebx
.already_ordered:
    ret

add_multi:
    push    ebp
    mov     ebp, esp
    sub     esp, 20
    push    ebx
    push    esi
    push    edi
    mov     eax, [ebp+8]
    mov     ebx, [ebp+12]
    call    get_maxmin
    movzx   esi, byte [eax]
    movzx   edi, byte [ebx]
    mov     [ebp-8],  esi
    mov     [ebp-12], edi
    lea     edx, [ebx+1]
    mov     [ebp-16], edx
    mov     edx, esi
    cmp     edx, 255
    je      .am_alloc
    inc     edx
.am_alloc:
    lea     ecx, [eax+1]
    push    ecx
    lea     eax, [edx+1]
    push    eax
    call    malloc
    add     esp, 4
    pop     ecx
    test    eax, eax
    jz      .am_err
    mov     [ebp-4], eax

    mov     edx, [ebp-8]
    cmp     edx, 255
    je      .am_setsize
    inc     edx
.am_setsize:
    mov     esi, [ebp-4]
    mov     [esi], dl
    xor     ebx, ebx
    mov     byte [ebp-20], 0

.am_p1:
    mov     edx, [ebp-12]
    cmp     ebx, edx
    jge     .am_p2
    movzx   eax, byte [ecx+ebx]
    mov     edi, [ebp-16]
    movzx   edx, byte [edi+ebx]
    add     eax, edx
    movzx   edx, byte [ebp-20]
    add     eax, edx
    mov     esi, [ebp-4]
    mov     [esi+1+ebx], al
    shr     eax, 8
    mov     [ebp-20], al
    inc     ebx
    jmp     .am_p1


.am_p2:
    mov     edx, [ebp-8]
    cmp     ebx, edx
    jge     .am_final
    movzx   eax, byte [ecx+ebx]
    movzx   edx, byte [ebp-20]
    add     eax, edx
    mov     esi, [ebp-4]
    mov     [esi+1+ebx], al
    shr     eax, 8
    mov     [ebp-20], al
    inc     ebx
    jmp     .am_p2

.am_final:
    mov     edx, [ebp-8]
    cmp     edx, 255
    je      .am_ok
    movzx   eax, byte [ebp-20]
    mov     esi, [ebp-4]
    mov     [esi+1+ebx], al

.am_ok:
    mov     eax, [ebp-4]
    jmp     .am_ret
.am_err:
    xor     eax, eax
.am_ret:
    pop     edi
    pop     esi
    pop     ebx
    add     esp, 20
    pop     ebp
    ret

rand_num:
    movzx   eax, word [STATE]
    movzx   ecx, word [MASK]
    and     ecx, eax
    mov     eax, ecx
    shr     eax, 8
    xor     cl, al
    test    cl, cl
    setnp   al
    movzx   ecx, word [STATE]
    shr     cx, 1
    test    al, al
    jz      .rn_no_msb
    or      cx, 0x8000
.rn_no_msb:
    mov     [STATE], cx
    mov     al, cl
    ret

PRmulti:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi
    push    edi


.pr_len:
    call    rand_num
    movzx   edi, al
    test    edi, edi
    jz      .pr_len
    lea     eax, [edi+1]
    push    eax
    call    malloc
    add     esp, 4
    test    eax, eax
    jz      .pr_err
    mov     ebx, eax
    mov     eax, edi
    mov     [ebx], al
    xor     esi, esi

.pr_fill:
    cmp     esi, edi
    jge     .pr_done
    call    rand_num
    mov     [ebx+1+esi], al
    inc     esi
    jmp     .pr_fill

.pr_done:
    mov     eax, ebx
    jmp     .pr_ret
.pr_err:
    xor     eax, eax
.pr_ret:
    pop     edi
    pop     esi
    pop     ebx
    pop     ebp
    ret

main:
    push    ebp
    mov     ebp, esp
    sub     esp, 12
    push    ebx
    push    esi
    push    edi

    mov     ebx, [ebp+8]
    mov     esi, [ebp+12]


    mov     dword [ebp-4], x_struct
    mov     dword [ebp-8], y_struct

    cmp     ebx, 2
    jl      .do_add

    mov     edi, [esi+4]


    cmp     byte [edi+0], '-'
    jne     .do_add
    cmp     byte [edi+2], 0
    jne     .do_add
    cmp     byte [edi+1], 'I'
    je      .mode_I
    cmp     byte [edi+1], 'R'
    je      .mode_R
    jmp     .do_add

.mode_I:
    call    getmulti_impl
    test    eax, eax
    jz      .exit_err
    mov     [ebp-4], eax
    call    getmulti_impl
    test    eax, eax
    jz      .exit_err
    mov     [ebp-8], eax
    jmp     .do_add

.mode_R:
    call    PRmulti
    test    eax, eax
    jz      .exit_err
    mov     [ebp-4], eax
    call    PRmulti
    test    eax, eax
    jz      .exit_err
    mov     [ebp-8], eax
    jmp     .do_add

.do_add:
    push    dword [ebp-4]
    call    print_multi
    add     esp, 4  
    push    dword [ebp-8]
    call    print_multi
    add     esp, 4
    push    dword [ebp-8]
    push    dword [ebp-4]
    call    add_multi
    add     esp, 8
    test    eax, eax
    jz      .exit_err
    mov     [ebp-12], eax
    push    eax
    call    print_multi
    add     esp, 4
    xor     eax, eax
    jmp     .main_exit

.exit_err:
    mov     eax, 1
.main_exit:
    pop     edi
    pop     esi
    pop     ebx
    add     esp, 12
    pop     ebp
    ret
