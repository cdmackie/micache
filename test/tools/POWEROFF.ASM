; POWEROFF.COM - switch the (emulated) machine off through the APM BIOS,
; so a scripted DOSBox-X / VirtualBox test run ends by itself.
; First it saves the text screen through the BIOS to the second hard disk
; (drive 81h, cyl 305, head 2: sector 1 'POFF', sectors 2-9 the screen), so
; the last screen of a run that ended early can be read, even when DOS's
; own disk writes can no longer be trusted. No second disk: nothing saved.
code    segment
        assume cs:code,ds:code
        org 100h
start:  push cs
        pop es
        mov bx,offset hdr
        mov ax,0301h
        mov cx,3141h            ; cyl 305 (131h), sector 1
        mov dx,0281h            ; head 2, drive 81h
        int 13h
        jc  apm
        mov ax,0B800h
        mov es,ax
        xor bx,bx
        mov ax,0308h
        mov cx,3142h
        mov dx,0281h
        int 13h
apm:    mov ax,5301h            ; APM: connect real-mode interface
        xor bx,bx
        int 15h
        mov ax,530Eh            ; APM: driver version 1.2
        xor bx,bx
        mov cx,0102h
        int 15h
        mov ax,5308h            ; APM: enable power management
        mov bx,1
        mov cx,1
        int 15h
        mov ax,5307h            ; APM: set power state of all devices
        mov bx,1
        mov cx,3                ; off
        int 15h
        mov dx,offset failed    ; still here: no APM
        mov ah,9
        int 21h
        int 20h
failed  db 'POWEROFF: APM power off failed',13,10,'$'
hdr     db 'POFF'
        db 508 dup (0)
code    ends
        end start
