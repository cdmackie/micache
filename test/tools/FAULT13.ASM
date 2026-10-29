; FAULT13.COM - INT 13h fault injector for testing MICACHE.
;
; Loaded BEFORE MICACHE, so it sits between MICACHE and the BIOS and sees
; every physical transfer MICACHE makes. Run once with no arguments to
; install; run again with a command to control the resident copy:
;
;   FAULT13            install
;   FAULT13 E d n c r  on drive d, starting with the n-th read/write from
;                      now, fail r calls in a row with code c. Each does the
;                      transfer and then, if a read, fills the whole buffer
;                      with 0EEh (a failed transfer can leave any data)
;   FAULT13 D d        on drive d, fail with 09h (DMA boundary) any transfer
;                      whose buffer crosses a 64K physical boundary, as a
;                      real floppy BIOS does (d = 255 turns it off)
;   FAULT13 C d        next read/write/change-status (16h) call for drive d
;                      returns 06h (disk changed) once
;   FAULT13 S          print counters: reads writes injected dmafails
;
; Drive numbers are decimal BIOS numbers: 0 = A:, 128 = C:.
; The control call is INT 13h AH=0FEh, CX='FT', returning CX='ok' and
; ES:BX -> the state block. INT 13h AH=0FDh is a write (as AH=3) that goes
; straight to the BIOS: as MICACHE passes unknown functions on, a test can
; use it to change the disk behind MICACHE's back.

code    segment
        assume cs:code,ds:code
        org 100h
start:  jmp init

; ---- resident state -------------------------------------------------------
old13   dd ?
state   label byte
errdrv  db 0FFh         ; drive for injected errors (0FFh = none)
errcnt  dw 0            ; calls until the first error
errcode db 0
errrep  dw 0            ; errors still to inject once started
dmadrv  db 0FFh         ; drive with DMA boundary checking
chgdrv  db 0FFh         ; drive with a pending disk change
nreads  dw 0
nwrites dw 0
ninj    dw 0
ndma    dw 0

; ---- resident handler -----------------------------------------------------
int13:  cmp ah,0FEh
        jne notctl
        cmp cx,'FT'
        jne notctl
        push cs
        pop es
        mov bx,offset state
        mov cx,'ok'
        clc
        retf 2

notctl: cmp ah,0FDh             ; direct write
        jne notdir
        mov ah,3
        jmp cs:old13

notdir: ; pending disk change?
        cmp dl,cs:chgdrv
        jne nochg
        cmp ah,2
        je  dochg
        cmp ah,3
        je  dochg
        cmp ah,16h
        jne nochg
dochg:  mov cs:chgdrv,0FFh
        mov ah,6
        stc
        retf 2

nochg:  cmp ah,2
        je  rw
        cmp ah,3
        je  rw
        jmp cs:old13

rw:     cmp ah,2
        jne cntw
        inc cs:nreads
        jmp short counted
cntw:   inc cs:nwrites
counted:
        ; DMA boundary check
        cmp dl,cs:dmadrv
        jne nodma
        push ax
        push cx
        push dx
        mov dx,es               ; start para = ES + BX/16
        mov cx,bx
        shr cx,1
        shr cx,1
        shr cx,1
        shr cx,1
        add dx,cx
        mov ah,al               ; bytes = AL * 512
        xor al,al
        shl ax,1
        mov cx,bx
        and cx,15
        add ax,cx               ; + offset within para
        dec ax
        shr ax,1
        shr ax,1
        shr ax,1
        shr ax,1
        add ax,dx               ; end para
        xor ax,dx
        test ax,0F000h
        pop dx
        pop cx
        pop ax
        jz  nodma
        inc cs:ndma
        mov ax,0900h
        stc
        retf 2

nodma:  ; injected error?
        cmp dl,cs:errdrv
        jne pass
        cmp cs:errcnt,1
        jbe fail
        dec cs:errcnt
pass:   jmp cs:old13

fail:   dec cs:errrep
        jnz more
        mov cs:errdrv,0FFh
more:   inc cs:ninj
        push ax                 ; do the transfer, then fail it
        pushf
        call cs:old13
        pop ax
        cmp ah,2
        jne nofill
        push cx
        push di
        mov di,bx
        mov ch,al               ; AL sectors * 512 bytes = AL * 256 words
        xor cl,cl
        mov ax,0EEEEh
        cld
        rep stosw
        pop di
        pop cx
nofill: mov ah,cs:errcode
        xor al,al
        stc
        retf 2

resend  label byte

; ---- transient part -------------------------------------------------------
init:   cld
        mov ah,0FEh             ; already installed?
        mov cx,'FT'
        int 13h
        cmp cx,'ok'
        je  control
        ; install
        mov ax,3513h
        int 21h
        mov word ptr old13,bx
        mov word ptr old13+2,es
        mov dx,offset int13
        mov ax,2513h
        int 21h
        mov dx,offset msginst
        mov ah,9
        int 21h
        mov dx,offset resend
        add dx,15
        mov cl,4
        shr dx,cl
        mov ax,3100h
        int 21h

control:                        ; ES:BX -> resident state
        mov di,bx
        mov si,81h
        call skipsp
        lodsb
        and al,0DFh             ; upper case
        cmp al,'E'
        je  cmde
        cmp al,'D'
        je  cmdd
        cmp al,'C'
        je  cmdc
        cmp al,'S'
        je  cmds
        mov dx,offset msgusage
        mov ah,9
        int 21h
        mov ax,4C01h
        int 21h

cmde:   call getnum
        push ax
        call getnum
        mov es:[di+errcnt-state],ax
        call getnum
        mov es:[di+errcode-state],al
        call getnum
        or  ax,ax
        jnz cmde1
        inc ax
cmde1:  mov es:[di+errrep-state],ax
        pop ax
        mov es:[di+errdrv-state],al
        jmp short ok
cmdd:   call getnum
        mov es:[di+dmadrv-state],al
        jmp short ok
cmdc:   call getnum
        mov es:[di+chgdrv-state],al
        jmp short ok
cmds:   mov ax,es:[di+nreads-state]
        call putnum
        mov ax,es:[di+nwrites-state]
        call putnum
        mov ax,es:[di+ninj-state]
        call putnum
        mov ax,es:[di+ndma-state]
        call putnum
        mov dx,offset crlf
        mov ah,9
        int 21h
ok:     mov ax,4C00h
        int 21h

skipsp: cmp byte ptr [si],' '
        jne sk1
        inc si
        jmp skipsp
sk1:    ret

getnum: call skipsp             ; decimal number from [si] -> AX
        xor ax,ax
gn1:    mov bl,[si]
        sub bl,'0'
        cmp bl,9
        ja  gn2
        mov cx,10
        mul cx
        xor bh,bh
        add ax,bx
        inc si
        jmp gn1
gn2:    ret

putnum: push ax                 ; print AX in decimal and a space
        mov bx,10
        xor cx,cx
pn1:    xor dx,dx
        div bx
        push dx
        inc cx
        or  ax,ax
        jnz pn1
pn2:    pop dx
        add dl,'0'
        mov ah,2
        int 21h
        loop pn2
        mov dl,' '
        mov ah,2
        int 21h
        pop ax
        ret

msginst  db 'FAULT13 installed',13,10,'$'
msgusage db 'usage: FAULT13 [E d n c r | D d | C d | S]',13,10,'$'
crlf     db 13,10,'$'

code    ends
        end start
