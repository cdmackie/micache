; WATCHDOG.COM - record where a hung test is stuck.
;
;   WATCHDOG n      install; n seconds from now, if the machine still takes
;                   timer interrupts, write a dump to the last track of the
;                   second hard disk (BIOS drive 81h, cyl 305, head 3):
;                     sector 1     header (below)
;                     sectors 2-9  the 80x25 text screen (B800:0000)
;
; The dump is written once, through the INT 13h vector as it was at install
; (so load this before FAULT13 and MICACHE: they are then bypassed), from the
; timer interrupt and on a stack of its own. A test that finishes in time
; powers off before it fires. No dump at all after a hang means interrupts
; were off, or the BIOS disk call could not run.
;
; Header: 'WDOG', then words: IP CS FLAGS AX BX CX DX SI DI BP DS ES SS SP,
; then the INT 13h vector (offset, segment) when the dump was taken, then the
; 32 words on the interrupted stack.
code    segment
        assume cs:code,ds:code
        org 100h
start:  jmp init

; ---- resident part ---------------------------------------------------------
old8    dd ?
old13   dd ?
ticks   dw 0
armed   db 0
oss     dw ?
osp     dw ?

hdr     db 'WDOG'
h_ip    dw ?
h_cs    dw ?
h_fl    dw ?
h_ax    dw ?
h_bx    dw ?
h_cx    dw ?
h_dx    dw ?
h_si    dw ?
h_di    dw ?
h_bp    dw ?
h_ds    dw ?
h_es    dw ?
h_ss    dw ?
h_sp    dw ?
h_v13   dd ?
h_stk   dw 32 dup (?)
        db 512 - ($ - hdr) dup (0)

int8:   pushf
        call cs:old8            ; the BIOS handler does the EOI
        cmp cs:armed,1
        je  chk
        iret
chk:    dec cs:ticks
        jz  fire
        iret

fire:   mov cs:armed,0
        mov cs:h_bp,bp
        push bp
        mov bp,sp               ; [bp+2] IP, [bp+4] CS, [bp+6] FLAGS
        mov cs:h_ax,ax
        mov cs:h_bx,bx
        mov cs:h_cx,cx
        mov cs:h_dx,dx
        mov cs:h_si,si
        mov cs:h_di,di
        mov cs:h_ds,ds
        mov cs:h_es,es
        mov cs:h_ss,ss
        lea ax,[bp+8]
        mov cs:h_sp,ax
        mov ax,[bp+2]
        mov cs:h_ip,ax
        mov ax,[bp+4]
        mov cs:h_cs,ax
        mov ax,[bp+6]
        mov cs:h_fl,ax
        ; the interrupted stack
        push ds
        mov ax,ss
        mov ds,ax
        lea si,[bp+8]
        push cs
        pop es
        mov di,offset h_stk
        mov cx,32
        cld
        rep movsw
        ; INT 13h vector now
        xor ax,ax
        mov ds,ax
        mov ax,ds:[13h*4]
        mov word ptr cs:h_v13,ax
        mov ax,ds:[13h*4+2]
        mov word ptr cs:h_v13+2,ax
        pop ds
        ; our own stack
        cli
        mov cs:oss,ss
        mov cs:osp,sp
        mov ax,cs
        mov ss,ax
        mov sp,offset stktop
        sti
        push cs                 ; header
        pop es
        mov bx,offset hdr
        mov ax,0301h
        mov cx,3141h            ; cyl 305 (131h), sector 1
        mov dx,0381h            ; head 3, drive 81h
        pushf
        call cs:old13
        mov ax,0B800h           ; screen
        mov es,ax
        xor bx,bx
        mov ax,0308h
        mov cx,3142h            ; sector 2
        mov dx,0381h
        pushf
        call cs:old13
        cli
        mov ss,cs:oss
        mov sp,cs:osp
        mov ax,cs:h_ax
        mov bx,cs:h_bx
        mov cx,cs:h_cx
        mov dx,cs:h_dx
        mov si,cs:h_si
        mov di,cs:h_di
        mov ds,cs:h_ds
        mov es,cs:h_es
        pop bp
        iret

        dw 256 dup (?)
stktop  label word

resend  label byte

; ---- transient part --------------------------------------------------------
init:   mov si,81h
        xor ax,ax
sk:     mov bl,[si]
        cmp bl,' '
        jne num
        inc si
        jmp sk
num:    mov bl,[si]
        sub bl,'0'
        cmp bl,9
        ja  gotn
        mov cx,10
        mul cx
        xor bh,bh
        add ax,bx
        inc si
        jmp num
gotn:   or  ax,ax
        jz  usage
        mov cx,182              ; 18.2 ticks a second
        mul cx
        mov cx,10
        div cx
        mov ticks,ax
        mov ax,3508h
        int 21h
        mov word ptr old8,bx
        mov word ptr old8+2,es
        mov ax,3513h
        int 21h
        mov word ptr old13,bx
        mov word ptr old13+2,es
        mov dx,offset int8
        mov ax,2508h
        int 21h
        mov armed,1
        mov dx,offset msginst
        mov ah,9
        int 21h
        mov dx,offset resend
        add dx,15
        mov cl,4
        shr dx,cl
        mov ax,3100h
        int 21h
usage:  mov dx,offset msgusage
        mov ah,9
        int 21h
        mov ax,4C01h
        int 21h

msginst  db 'WATCHDOG armed',13,10,'$'
msgusage db 'usage: WATCHDOG seconds',13,10,'$'

code    ends
        end start
