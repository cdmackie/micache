; CHG13.COM - probe a BIOS's floppy change line on drive A:
;
;   CHG13           prints one line: the INT 13h AH=16h status (in hex) at
;                   each step of:  chk  read c0  chk  chk  read c5  chk
;                   read c0  chk  (00 = not changed, 06 = changed)
;
; DOS checks AH=16h before using a floppy, and MICACHE flushes the drive
; whenever it answers 06h, so this shows how often a cache gets flushed.
code    segment
        assume cs:code,ds:code
        org 100h
start:  call chk
        mov ch,0
        call rd
        call chk
        call chk
        mov ch,5
        call rd
        call chk
        mov ch,0
        call rd
        call chk
        mov dx,offset crlf
        mov ah,9
        int 21h
        int 20h

chk:    mov dl,'C'              ; "C=xx "
        call pch
        mov ah,16h
        xor dl,dl
        int 13h
        jmp short show
rd:     mov dl,'R'              ; "R=xx " read cyl CH, head 0, sector 1
        call pch
        mov ax,0201h
        mov cl,1
        xor dx,dx
        push cs
        pop es
        mov bx,offset buf
        int 13h
show:   mov al,ah
        call hex
        mov dl,' '
pch:    push ax
        mov ah,2
        int 21h
        pop ax
        ret
hex:    push ax
        mov cl,4
        shr al,cl
        call nib
        pop ax
        and al,0Fh
nib:    add al,'0'
        cmp al,'9'
        jbe nib1
        add al,7
nib1:   mov dl,al
        mov ah,2
        int 21h
        ret

crlf    db 13,10,'$'
buf     db 512 dup (?)
code    ends
        end start
