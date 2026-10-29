; POWEROFF.COM - switch the (emulated) machine off through the APM BIOS,
; so a scripted DOSBox-X / VirtualBox test run ends by itself.
code    segment
        assume cs:code,ds:code
        org 100h
start:  mov ax,5301h            ; APM: connect real-mode interface
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
code    ends
        end start
