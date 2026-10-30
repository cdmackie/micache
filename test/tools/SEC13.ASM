; SEC13.COM - raw INT 13h sector reads and writes for scripted cache tests.
;
;   SEC13 R d c h s n FILE   read n sectors at drive d, cyl c, head h,
;                            sector s; append the data to FILE
;   SEC13 W d c h s n v      write n sectors of pattern v (byte i of the
;                            k-th sector = v + k*7 + i*3, low 8 bits)
;   SEC13 X d c h s n v      the same, but with INT 13h AH=0FDh, which
;                            FAULT13 sends straight to the BIOS (so it
;                            changes the disk behind MICACHE's back)
;   SEC13 F d c h s n        format the track with n 512-byte sectors
;                            (s is ignored)
;
; Numbers are decimal (d: 0 = A:, 128 = C:). Prints one line to stdout:
; the command and "OK" or "ERR xx" (hex BIOS error), errorlevel 0 or 1.
; The buffer never crosses a 64K boundary, so a pass-through transfer
; cannot fail a DMA check of its own.
code    segment
        assume cs:code,ds:code,es:code
        org 100h
start:  cld
        ; choose a buffer that does not cross 64K
        mov bx,offset buf1
        call crosses
        jz  bufok
        mov bx,offset buf2
bufok:  mov bufp,bx
        mov si,81h
        call skipsp
        lodsb
        and al,0DFh
        mov cmd,al
        call getnum
        mov drv,al
        call getnum
        mov cyl,ax
        call getnum
        mov head,al
        call getnum
        mov sect,al
        call getnum
        mov nsec,al
        cmp cmd,'R'
        je  doread
        cmp cmd,'F'
        je  dofmt
        call getnum
        mov patv,al
        call fill
        mov ah,3
        cmp cmd,'W'
        je  dowr
        mov ah,0FDh
dowr:   call bios
        jmp report

dofmt:  mov di,bufp             ; address fields: C H R N per sector
        mov cl,1
ff1:    mov al,byte ptr cyl
        stosb
        mov al,head
        stosb
        mov al,cl
        stosb
        mov al,2                ; N = 2: 512 bytes
        stosb
        inc cl
        cmp cl,nsec
        jbe ff1
        mov ah,5
        call bios
        jmp report

doread: mov ah,2
        call bios
        jc  report
        push ax                 ; append to file
        call skipsp
        mov dx,si
fn1:    lodsb                   ; terminate the name
        cmp al,' '
        ja  fn1
        mov byte ptr [si-1],0
        mov ax,3D01h
        int 21h
        jnc fopen
        mov ah,3Ch
        xor cx,cx
        int 21h
fopen:  mov bx,ax
        mov ax,4202h
        xor cx,cx
        xor dx,dx
        int 21h
        mov ch,nsec             ; nsec * 512 bytes
        xor cl,cl
        shl cx,1
        mov dx,bufp
        mov ah,40h
        int 21h
        mov ah,3Eh
        int 21h
        pop ax
        clc

report: pushf
        push ax
        mov dl,cmd              ; echo the command
        mov ah,2
        int 21h
        mov dx,offset msgsp
        mov ah,9
        int 21h
        pop ax
        popf
        jc  rerr
        mov dx,offset msgok
        mov ah,9
        int 21h
        mov ax,4C00h
        int 21h
rerr:   mov al,ah
        push ax
        mov dx,offset msgerr
        mov ah,9
        int 21h
        pop ax
        call puthex
        mov dx,offset crlf
        mov ah,9
        int 21h
        mov ax,4C01h
        int 21h

bios:   push ax                 ; AH = function
        mov ax,cyl
        mov ch,al
        mov cl,ah               ; cyl bits 8-9 -> CL bits 6-7
        ror cl,1
        ror cl,1
        and cl,0C0h
        or  cl,sect
        mov dh,head
        mov dl,drv
        mov bx,bufp
        pop ax
        mov al,nsec
        int 13h
        ret

fill:   mov di,bufp             ; pattern into the buffer
        xor dx,dx               ; k
        mov bl,nsec
fl1:    mov cx,512
        mov al,patv
        mov ah,dl               ; v + k*7
        mov bh,7
        push ax
        mov al,dl
        mul bh
        mov bh,al
        pop ax
        add al,bh
fl2:    stosb
        add al,3
        loop fl2
        inc dl
        dec bl
        jnz fl1
        ret

crosses: ; ZF = 0 if 36 sectors at DS:BX cross a 64K boundary
        mov ax,ds
        mov dx,bx
        mov cl,4
        shr dx,cl
        add ax,dx               ; start para
        mov dx,ax
        add dx,(36*512)/16
        xor dx,ax
        test dx,0F000h
        ret

skipsp: cmp byte ptr [si],' '
        jne sk1
        inc si
        jmp skipsp
sk1:    ret

getnum: call skipsp
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

puthex: push ax
        mov cl,4
        shr al,cl
        call hexd
        pop ax
        and al,15
hexd:   add al,'0'
        cmp al,'9'
        jbe hx1
        add al,7
hx1:    mov dl,al
        mov ah,2
        int 21h
        ret

msgsp   db ' $'
msgok   db 'OK',13,10,'$'
msgerr  db 'ERR $'
crlf    db 13,10,'$'
cmd     db ?
drv     db ?
cyl     dw ?
head    db ?
sect    db ?
nsec    db ?
patv    db ?
bufp    dw ?
buf1    db 36*512 dup (?)
buf2    db 36*512 dup (?)
code    ends
        end start
