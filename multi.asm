; multi.asm  —  Multi-Precision Integer I/O and Adder
; x86 32-bit, NASM, Linux cdecl
; Build:
;   nasm -f elf32 multi.asm -o multi.o
;   gcc -m32 multi.o -o multi

global main
extern printf, fgets, malloc, stdin, putchar

; ─────────────────────────────────────────────────────────────
section .data
; ── Default test structs ──────────────────────────────────────
x_struct:   db 5
x_num:      db 0xaa, 1, 2, 0x44, 0x4f

y_struct:   db 6
y_num:      db 0xaa, 1, 2, 3, 0x44, 0x4f

; ── LFSR state (Fibonacci, 16-bit)  taps: 16,15,13,4 → 0xB400 ─
STATE:  dw  0xACE1
MASK:   dw  0xB400

; ── Format strings ────────────────────────────────────────────
fmt_byte:   db  "%02hhx", 0
fmt_nl:     db  10, 0

; ─────────────────────────────────────────────────────────────
section .bss
BUFSIZE     equ 512
inputbuf:   resb BUFSIZE

; ─────────────────────────────────────────────────────────────
section .text

; ════════════════════════════════════════════════════════════
; hex_char_to_nibble
;   IN : al = ASCII hex character ('0'-'9','a'-'f','A'-'F')
;   OUT: al = nibble value 0-15
;   Clobbers: al only
; ════════════════════════════════════════════════════════════
hex_char_to_nibble:
    cmp al, '9'
    jle .digit
    or  al, 0x20        ; fold to lower-case
    sub al, 'a'-10
    ret
.digit:
    sub al, '0'
    ret

; ════════════════════════════════════════════════════════════
; print_multi(struct multi *p)   [cdecl, 1 arg on stack]
;   Prints number in hex big-endian (MSB first), skips leading
;   zero bytes (but always prints at least one byte), then '\n'.
; ════════════════════════════════════════════════════════════
print_multi:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi

    mov     esi, [ebp+8]            ; esi = struct*
    movzx   ecx, byte [esi]         ; ecx = size
    lea     ebx, [esi+1]            ; ebx = &num[0]

    ; find highest non-zero byte index (always print at least index 0)
    mov     eax, ecx
    dec     eax                     ; start at last index
.pm_skip:
    cmp     eax, 0
    jle     .pm_print
    cmp     byte [ebx+eax], 0
    jne     .pm_print
    dec     eax
    jmp     .pm_skip

.pm_print:
    ; print bytes from index eax down to 0
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
    jns     .pm_loop                ; loop while ecx >= 0

    push    fmt_nl
    call    printf
    add     esp, 4

    pop     esi
    pop     ebx
    pop     ebp
    ret

; ════════════════════════════════════════════════════════════
; getmulti_impl() [cdecl, no args]
;   Reads one line from stdin.
;   Returns eax = malloc'd struct multi*, or 0 on error.
;
;   Parsing strategy (little-endian storage):
;     digits in string are big-endian → we walk left→right and
;     store at decreasing byte indices (num[nbytes-1] = MSB,
;     num[0] = LSB).
;     Odd digit count: treat leading digit as a lone low nibble
;     (high nibble = 0).
; ════════════════════════════════════════════════════════════
getmulti_impl:
    push    ebp
    mov     ebp, esp
    sub     esp, 8          ; [ebp-4]=ndigits  [ebp-8]=nbytes
    push    ebx
    push    esi
    push    edi

    ; ── fgets ──────────────────────────────────────────────
    push    dword [stdin]
    push    BUFSIZE
    push    inputbuf
    call    fgets
    add     esp, 12
    test    eax, eax
    jz      .gm_err

    ; ── count hex digits ────────────────────────────────────
    mov     esi, inputbuf
    xor     ecx, ecx
.gm_cnt:
    movzx   eax, byte [esi+ecx]
    cmp     al, 10          ; '\n'
    je      .gm_cnt_done
    cmp     al, 13          ; '\r'
    je      .gm_cnt_done
    cmp     al, 0
    je      .gm_cnt_done
    inc     ecx
    jmp     .gm_cnt
.gm_cnt_done:
    mov     [ebp-4], ecx            ; ndigits
    ; nbytes = (ndigits+1)/2
    mov     eax, ecx
    inc     eax
    shr     eax, 1
    test    eax, eax
    jz      .gm_err
    mov     [ebp-8], eax            ; nbytes

    ; ── malloc(nbytes+1) ────────────────────────────────────
    lea     eax, [eax+1]
    push    eax
    call    malloc
    add     esp, 4
    test    eax, eax
    jz      .gm_err
    mov     ebx, eax                ; ebx = struct*

    mov     ecx, [ebp-8]            ; nbytes
    mov     [ebx], cl               ; struct.size = nbytes

    ; ── parse ───────────────────────────────────────────────
    ; esi = inputbuf, edi = dest byte index (starts at nbytes-1)
    mov     edi, [ebp-8]
    dec     edi                     ; edi = MSB slot index
    mov     ecx, [ebp-4]            ; ecx = remaining digit count

    ; Handle odd leading digit (produces a byte with high nibble=0)
    test    ecx, 1
    jz      .gm_pairs
    movzx   eax, byte [esi]
    inc     esi
    dec     ecx
    call    hex_char_to_nibble      ; al = low nibble, high=0
    mov     [ebx+1+edi], al
    dec     edi

.gm_pairs:
    cmp     ecx, 0
    jle     .gm_done
    ; high nibble
    movzx   eax, byte [esi]
    inc     esi
    push    ebx                     ; save struct ptr (printf may clobber)
    call    hex_char_to_nibble
    shl     al, 4
    mov     dl, al                  ; dl = high nibble * 16
    pop     ebx
    ; low nibble
    movzx   eax, byte [esi]
    inc     esi
    push    ebx
    call    hex_char_to_nibble      ; al = low nibble
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

; ════════════════════════════════════════════════════════════
; get_maxmin  [NOT cdecl]
;   IN : eax = struct* A,  ebx = struct* B
;   OUT: eax = ptr to longer (or equal) struct
;        ebx = ptr to shorter struct
;   Clobbers: ecx, edx
; ════════════════════════════════════════════════════════════
get_maxmin:
    movzx   ecx, byte [eax]
    movzx   edx, byte [ebx]
    cmp     ecx, edx
    jge     .already_ordered
    xchg    eax, ebx
.already_ordered:
    ret

; ════════════════════════════════════════════════════════════
; add_multi(struct multi *p, struct multi *q)  [cdecl]
;   Returns eax = malloc'd struct multi* containing p+q
;
;   Carry is kept in a memory byte [ebp-20] to avoid CF being
;   clobbered by cmp/mov instructions between adc uses.
; ════════════════════════════════════════════════════════════
add_multi:
    push    ebp
    mov     ebp, esp
    sub     esp, 20
    ; [ebp- 4] = result struct*
    ; [ebp- 8] = max_len
    ; [ebp-12] = min_len
    ; [ebp-16] = min array base ptr
    ; [ebp-20] = carry byte
    push    ebx
    push    esi
    push    edi

    ; ── get max/min pointers ─────────────────────────────────
    mov     eax, [ebp+8]
    mov     ebx, [ebp+12]
    call    get_maxmin              ; eax=max struct, ebx=min struct

    movzx   esi, byte [eax]
    movzx   edi, byte [ebx]
    mov     [ebp-8],  esi           ; max_len
    mov     [ebp-12], edi           ; min_len
    lea     edx, [ebx+1]
    mov     [ebp-16], edx           ; min array base

    ; ── compute array_size, malloc ───────────────────────────
    mov     edx, esi                ; max_len
    cmp     edx, 255
    je      .am_alloc
    inc     edx
.am_alloc:                          ; edx = array_size
    ; save max array base before malloc clobbers eax
    lea     ecx, [eax+1]            ; max array base
    push    ecx                     ; [esp] = max array base
    lea     eax, [edx+1]            ; malloc size = array_size + 1
    push    eax
    call    malloc
    add     esp, 4
    pop     ecx                     ; restore max array base
    test    eax, eax
    jz      .am_err
    mov     [ebp-4], eax            ; result struct*

    ; set result.size
    mov     edx, [ebp-8]
    cmp     edx, 255
    je      .am_setsize
    inc     edx
.am_setsize:
    mov     esi, [ebp-4]
    mov     [esi], dl

    ; ── byte-wise addition, carry stored in memory ────────────
    ; ecx = max array base (still valid — not touched since pop ecx)
    xor     ebx, ebx                ; i = 0
    mov     byte [ebp-20], 0        ; carry = 0

    ; Phase 1: i in [0, min_len) — add max[i] + min[i] + carry
.am_p1:
    mov     edx, [ebp-12]
    cmp     ebx, edx
    jge     .am_p2

    movzx   eax, byte [ecx+ebx]     ; max[i]
    mov     edi, [ebp-16]
    movzx   edx, byte [edi+ebx]     ; min[i]
    add     eax, edx                ; sum = max[i] + min[i]  (no overflow yet)
    movzx   edx, byte [ebp-20]
    add     eax, edx                ; sum += carry
    ; store low byte of sum as result[i]
    mov     esi, [ebp-4]
    mov     [esi+1+ebx], al
    ; new carry = (sum >> 8) & 1  → since max is 255+255+1=511 < 512, bit 8 only
    shr     eax, 8
    mov     [ebp-20], al            ; save carry

    inc     ebx
    jmp     .am_p1

    ; Phase 2: i in [min_len, max_len) — add max[i] + carry
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
    ; result[max_len] = carry, if room exists
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

; ════════════════════════════════════════════════════════════
; rand_num  [NOT cdecl]
;   Returns next 8 pseudorandom bits in al.
;   Modifies STATE.  Clobbers: eax, ecx.
; ════════════════════════════════════════════════════════════
rand_num:
    movzx   eax, word [STATE]
    movzx   ecx, word [MASK]
    and     ecx, eax            ; masked bits
    ; parity of 16-bit value in ecx:
    mov     eax, ecx
    shr     eax, 8
    xor     cl, al              ; cl = XOR of two halves
    ; now parity of cl determines new bit:
    ;   PF=1 → even parity → new MSB = 0
    ;   PF=0 → odd  parity → new MSB = 1
    ; But "parity" of the LFSR means XOR of all tapped bits.
    ; We want: new_bit = XOR of all tapped bits = parity (odd count → 1)
    ; parity flag: PF=1 when low byte has even number of 1-bits
    ; So: new_bit = NOT PF
    test    cl, cl              ; sets PF based on parity of cl
    ; new_bit: 0 if PF=1 (even), 1 if PF=0 (odd)
    setnp   al                  ; al = 1 if odd parity (PF=0)
    ; Shift STATE right, set bit 15 to new_bit
    movzx   ecx, word [STATE]
    shr     cx, 1
    ; set bit 15 if al=1
    test    al, al
    jz      .rn_no_msb
    or      cx, 0x8000
.rn_no_msb:
    mov     [STATE], cx
    mov     al, cl              ; return low byte of new STATE
    ret

; ════════════════════════════════════════════════════════════
; PRmulti()  [cdecl, no args]
;   Returns eax = malloc'd struct multi* with random content.
; ════════════════════════════════════════════════════════════
PRmulti:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi
    push    edi

    ; Generate non-zero length byte
.pr_len:
    call    rand_num
    movzx   edi, al             ; edi = n (byte length)
    test    edi, edi
    jz      .pr_len

    ; malloc(n+1)
    lea     eax, [edi+1]
    push    eax
    call    malloc
    add     esp, 4
    test    eax, eax
    jz      .pr_err
    mov     ebx, eax
    mov     eax, edi
    mov     [ebx], al           ; struct.size = n  (al = low byte of edi)

    ; Fill n bytes
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

; ════════════════════════════════════════════════════════════
; main(int argc, char **argv)
; ════════════════════════════════════════════════════════════
main:
    push    ebp
    mov     ebp, esp
    sub     esp, 12             ; [ebp-4]=p1  [ebp-8]=p2  [ebp-12]=result
    push    ebx
    push    esi
    push    edi

    mov     ebx, [ebp+8]        ; argc
    mov     esi, [ebp+12]       ; argv

    ; default mode
    mov     dword [ebp-4], x_struct
    mov     dword [ebp-8], y_struct

    cmp     ebx, 2
    jl      .do_add             ; no args → default

    mov     edi, [esi+4]        ; argv[1]

    ; check for "-I"
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
