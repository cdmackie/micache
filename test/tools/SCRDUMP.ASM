; SCRDUMP.COM - append the 80x25 text screen to C:\SCREEN.TXT, one line per
; row with trailing blanks removed, so a scripted test can see what programs
; wrote with the BIOS (which DOS redirection cannot capture).
code    segment
        assume cs:code,ds:code
        org 100h
start:  mov ax,3D01h            ; open for write
        mov dx,offset fname
        int 21h
        jnc opened
        mov ah,3Ch              ; else create
        xor cx,cx
        int 21h
        jc  done
opened: mov bx,ax
        mov ax,4202h            ; seek to end
        xor cx,cx
        xor dx,dx
        int 21h
        push ds
        mov ax,0B800h
        mov ds,ax
        xor si,si
        mov bp,25               ; rows
row:    push cs
        pop es
        mov di,offset line
        mov cx,80
        xor dx,dx               ; length to last non-blank
col:    lodsw
        stosb
        inc dx
        cmp al,' '
        je  blank
        mov cs:last,dx
blank:  loop col
        push ds
        push cs
        pop ds
        mov di,offset line
        add di,last
        mov word ptr [di],0A0Dh
        mov cx,last
        add cx,2
        mov dx,offset line
        mov ah,40h
        int 21h
        mov last,0
        pop ds
        dec bp
        jnz row
        pop ds
        mov ah,3Eh
        int 21h
done:   int 20h
fname   db 'C:\SCREEN.TXT',0
last    dw 0
line    db 84 dup (?)
code    ends
        end start
