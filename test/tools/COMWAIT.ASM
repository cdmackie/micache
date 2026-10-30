; COMWAIT.COM - ask the test host for something over COM1 and wait for it.
;
;   COMWAIT text    send "text" and CR LF on COM1 (9600 8N1), then wait until
;                   a byte comes back: the host has done what was asked.
;
; Under VirtualBox, vbrun.sh serves COM1 and answers "SWAP n" by putting
; floppy image FDn.IMG in drive A: (a real media change). Ports are driven
; directly, with interrupts left alone. No answer ever: WATCHDOG's timeout.
code    segment
        assume cs:code,ds:code
        org 100h
COM     equ 3F8h
start:  mov dx,COM+3            ; 9600 baud: DLAB on, divisor 12
        mov al,80h
        out dx,al
        mov dx,COM
        mov al,12
        out dx,al
        inc dx
        xor al,al
        out dx,al
        mov dx,COM+3            ; 8N1, DLAB off
        mov al,03h
        out dx,al
        mov dx,COM+4            ; DTR, RTS
        mov al,03h
        out dx,al
        mov dx,COM              ; drop anything already received
flush:  add dx,5
        in  al,dx
        sub dx,5
        test al,1
        jz  send
        in  al,dx
        jmp flush

send:   mov si,81h              ; command tail, skipping leading blanks
skip:   lodsb
        cmp al,' '
        je  skip
next:   cmp al,13
        je  eol
        call putc
        lodsb
        jmp next
eol:    mov al,13
        call putc
        mov al,10
        call putc

        mov dx,COM+5            ; wait for the answer
wait1:  in  al,dx
        test al,1
        jz  wait1
        mov dx,COM
        in  al,dx
        int 20h

putc:   push ax                 ; AL out on COM1, once the line is free
        mov dx,COM+5
putc1:  in  al,dx
        test al,20h
        jz  putc1
        pop ax
        mov dx,COM
        out dx,al
        ret

code    ends
        end start
