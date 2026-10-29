; DFPROBE.COM - check a cached INT 13h read is right when the caller has the
; direction flag set. Reads 4 sectors of C: (cyl 0, head 1, sector 1: the
; boot sector and FAT, read only) twice with DF clear to get them cached,
; then again with DF set into a buffer between guard bytes. Prints
; "DFPROBE OK" if that copy matches and the guards are intact, else
; "DFPROBE BAD", and sets errorlevel 1.
code    segment
        assume cs:code,ds:code,es:code
        org 100h
start:  cld
        push cs
        pop es
        mov bx,offset buf1
        call rd
        mov bx,offset buf1
        call rd
        ; guards and target
        mov di,offset guard1
        mov cx,GLEN*2+2048
        mov al,55h
        rep stosb
        mov bx,offset buf2
        std
        call rd
        cld
        ; check
        mov si,offset guard1
        mov cx,GLEN
        call isguard
        jne bad
        mov si,offset guard2
        mov cx,GLEN
        call isguard
        jne bad
        mov si,offset buf1
        mov di,offset buf2
        mov cx,2048
        repe cmpsb
        jne bad
        mov dx,offset msgok
        mov ah,9
        int 21h
        mov ax,4C00h
        int 21h
bad:    cld
        mov dx,offset msgbad
        mov ah,9
        int 21h
        mov ax,4C01h
        int 21h

rd:     mov ax,0204h            ; read 4 sectors
        mov cx,0001h            ; cyl 0, sector 1
        mov dx,0180h            ; head 1, drive 80h
        int 13h
        ret

isguard: cld
        lodsb
        cmp al,55h
        jne ig1
        loop isguard
        cmp al,al               ; ZF = 1: all guard
ig1:    ret

msgok   db 'DFPROBE OK',13,10,'$'
msgbad  db 'DFPROBE BAD',13,10,'$'
GLEN    equ 1024
buf1    db 2048 dup (0)
guard1  db GLEN dup (?)
buf2    db 2048 dup (?)
guard2  db GLEN dup (?)
code    ends
        end start
