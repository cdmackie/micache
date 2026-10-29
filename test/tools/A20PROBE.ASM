; A20PROBE.COM - check cached INT 13h calls leave the XMS A20 local-enable
; count balanced. Needs HIMEM.SYS without DOS=HIGH (so A20 starts off).
; Does an XMS local enable, makes 20 cached reads of C:, does one local
; disable, then asks XMS whether A20 is on. It should be off again:
; prints "A20PROBE OK", else "A20PROBE BAD" (errorlevel 1). Prints
; "A20PROBE NOXMS" (errorlevel 2) without an XMS driver.
code    segment
        assume cs:code,ds:code,es:code
        org 100h
start:  cld
        mov ax,4300h
        int 2Fh
        cmp al,80h
        jne noxms
        mov ax,4310h
        int 2Fh
        mov word ptr xms,bx
        mov word ptr xms+2,es
        push cs
        pop es
        mov ah,5                ; local enable A20
        call dword ptr xms
        mov cx,20
again:  push cx
        mov ax,0201h
        mov cx,0001h
        mov dx,0180h
        mov bx,offset buf
        int 13h
        pop cx
        loop again
        mov ah,6                ; local disable A20
        call dword ptr xms
        mov ah,7                ; query A20
        call dword ptr xms
        or  ax,ax
        jnz bad
        mov dx,offset msgok
        mov ah,9
        int 21h
        mov ax,4C00h
        int 21h
bad:    mov dx,offset msgbad
        mov ah,9
        int 21h
        mov ah,6                ; try to leave A20 as we found it
        call dword ptr xms
        mov ax,4C01h
        int 21h
noxms:  mov dx,offset msgnox
        mov ah,9
        int 21h
        mov ax,4C02h
        int 21h

xms     dd ?
msgok   db 'A20PROBE OK',13,10,'$'
msgbad  db 'A20PROBE BAD',13,10,'$'
msgnox  db 'A20PROBE NOXMS',13,10,'$'
buf     db 512 dup (?)
code    ends
        end start
