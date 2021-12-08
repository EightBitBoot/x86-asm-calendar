.MODEL TINY

; Insert a character with a specified color at the current vram index (di)
; di is incremented accordingly
insert_char_m MACRO char, color
    mov byte ptr es:[di], char   ; move the character to vram
    inc di
    mov byte ptr es:[di], color  ; move the color to vram
    inc di
ENDM

draw_char_at_m MACRO char, x, y
    mov ax, char
    push ax
    mov dh, x
    mov dl, y
    call draw_row_col
    add sp, 2          ; Drop the character passed on the stack
ENDM

draw_char_at_dx_m MACRO char
    mov ax, char
    push ax
    call draw_row_col
    add sp, 2          ; Drop the character passed on the stack
ENDM

.DATA

.CODE
ORG 100h
start:
    jmp main

; Params: color - word on the stack before return address
clear_screen PROC
    xor di, di ; 0 vram index
    push ax    ; Store ax for later
    mov si, sp
    mov ax, [si+4]

    mov cx, 80*25
clear_loop:
    insert_char_m 20h, al
    loop clear_loop

    pop ax     ; Restore ax

    ret
ENDP clear_screen

; Top left is 0,0
;
; Params: x    - dh (row)
;         y    - dl (col)
;         char - word on stack before return address
draw_row_col PROC
    push ax          ; Store ax for later
    push bx          ; Store bx for later

    mov al, dh       ; move row into al
    mov bl, 160
    mul bl           ; multiply x(row) by row length
    push ax          ; push ax so it can be used to multiply the column by 2
    xor ax, ax
    mov al, dl       ; move y(column; dh) to al
    mov bl, 2
    mul bl           ; multiply column by 2 (to account for color bytes in vram)
    pop bx           ; pop multiplied row into bx
    add ax, bx       ; add horizontal and vertical offsets to get final offset

    mov si, sp       ; store the stack pointer in si
    mov bx, [si+6]   ; get character from stack
    xchg ax, bx

    mov byte ptr es:[bx], al ; render the characer

    pop bx                   ; restore bx
    pop ax                   ; restore ax

    ret
ENDP draw_row_col

draw_border PROC
    xor di, di            ; 0 vram index

    ; Draw top border
    insert_char_m 0C9h, 70h ; Upper-left corner

    mov cx, 78            ; stop one character short of the end for the top-right corner
top_loop:
    insert_char_m 0CDh, 70h ; horizontal double line
    loop top_loop

    insert_char_m 0BBh, 70h ; upper-right corner

    ; Draw Sides
    mov cx, 23            ; 23 middle lines
sides_loop:
    insert_char_m 0BAh, 70h ; vertical dobule line
    add di, 78*2          ; skip 78 characters between sides (*2 for char & format)
    insert_char_m 0BAh, 70h ; verticle double line
    loop sides_loop

    ; Draw bottom border
    insert_char_m 0C8h, 70h ; Bottom-left corner

    mov cx, 78
bottom_loop:
    insert_char_m 0CDh, 70h ; horizontal double line
    loop bottom_loop

    insert_char_m 0BCh, 70h ; Bottom-left corner

    ret
ENDP draw_border

main PROC
    mov ax, 0B800h
    mov es, ax;      store vram segment in es

    mov ah, 01h   ; Set text-mode cursor shape
    mov cx, 2607h ; bit 5 of ch indicates invisible cursor, cursor from scanline 6 to 7
    int 10h       ; Bios interrupt

    ; Draw the background elements
    mov ax, 70h
    push ax
    call clear_screen
    add sp, 2

    call draw_border

    draw_char_at_m 'S', 3, 30
    draw_char_at_m 'u', 3, 31
    
    draw_char_at_m 'M', 3, 33
    draw_char_at_m 'o', 3, 34

    draw_char_at_m 'T', 3, 36
    draw_char_at_m 'u', 3, 37

    draw_char_at_m 'W', 3, 39
    draw_char_at_m 'e', 3, 40
    
    draw_char_at_m 'T', 3, 42
    draw_char_at_m 'h', 3, 43
    
    draw_char_at_m 'F', 3, 45
    draw_char_at_m 'r', 3, 46
    
    draw_char_at_m 'S', 3, 48
    draw_char_at_m 'a', 3, 49

    mov dh, 5
    mov dl, 30

    mov cx, 42
days_loop:
    cmp dl, 51
    jne no_adjust
    add dh, 2
    mov dl, 30
no_adjust:
    push ax
    draw_char_at_dx_m '_'
    pop ax
    add dl, 1
    push ax
    draw_char_at_dx_m '_'
    pop ax
    add dl, 2
    loop days_loop

main_loop:
    mov ah, 00h ; Get keycode
    int 16h     ; Bios interrupt


    cmp al, 'q'
    jz  done    ; If the key pressed was q, quit the program

    cmp al, 'Q'
    jz  done    ; If the key pressed was Q, quit the program

    jmp main_loop

done:
    mov ax, 07h ; Change back to white text on black background
    push ax
    call clear_screen
    add sp, 2

    mov ah, 01h    ; Set text-mode cursor shape
    mov cx, 0607h ; Cursor from scanline 6 to 7 (basic underline)
    int 10h       ; Bios interrupt

    mov ah, 00h ; Terminate program
    int 21h     ; Software interrupt

ENDP main

END start