.MODEL TINY

; Insert a character with a specified color at the current vram index (di)
; di is incremented accordingly
insert_char_m MACRO char, color
    mov byte ptr es:[di], char   ; move the character to vram
    inc di
    mov byte ptr es:[di], color  ; move the color to vram
    inc di
ENDM

draw_char_at_m MACRO char, row, col
    push si        ; Save si to restore later
    push dx        ; Save dx to restore later

    mov dh, row    ; Load row into dh
    mov dl, col    ; Load col into dl
    push dx        ; Push the coordinates to the stack
    xor dh, dh     ; Clear dh so dx can store just the character to draw
    mov dl, char   ; Load character into dl
    push dx        ; Push the character to the stack

    mov dx, [si+4] ; Restore dx to previous value
    mov si, [si+6] ; Restore si to previous value
    
    call draw_row_col

    add sp, 8      ; Drop the four values pushed to the stack: old si, old dx, coordinates, character
ENDM

draw_char_at_dx_m MACRO char
    push si        ; Save si to restore later
    push bx        ; Save bx to restore later 

    push dx        ; Push the coordinates to the stack
    xor bh, bh     ; Clear dh so dx can store just the character to draw
    mov bl, char   ; Loaad the character into bl
    push bx        ; Push the character to the stack

    mov bx, [si+4] ; Restore bx to previous value
    mov si, [si+4] ; Restore si to previous value

    call draw_row_col

    add sp, 8      ; Drop the three values pushed to the stack: old si, old dx, coordinates, character
ENDM

.DATA
; Month Names
jan_name_v db "January",0
feb_name_v db "Febuary",0
mar_name_v db "March",0
apr_name_v db "April",0
may_name_v db "May",0
jun_name_v db "June",0
jul_name_v db "July",0
aug_name_v db "August",0
sep_name_v db "September",0
oct_name_v db "October",0
nov_name_v db "November",0
dec_name_v db "December",0
; Array of month name pointers
month_name_ptrs_v dw offset jan_name_v, offset feb_name_v, offset mar_name_v, offset apr_name_v, offset may_name_v, offset jun_name_v, offset jul_name_v, offset aug_name_v, offset sep_name_v, offset oct_name_v, offset nov_name_v, offset dec_name_v

; Number of days in each month
month_lens_v db 31,28,31,30,31,30,31,31,30,31,30,31

; Current Month
curr_mon_v db ?
; Current Year
curr_yer_v dw ?

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

; Draw an arbitrary character at given coordinates
; Top left corner is at 0,0
; 
; Parameters:
;     character - the character to draw
;                 low byte of the word below return address on stack
;
;     row       - the row to draw the character at
;                 high byte of the word below the character on stack
;
;     col       - the col to draw the character at
;                 low byte of the word below the character on stack
;
draw_row_col PROC
    push ax                  ; Store ax to restore later
    push bx                  ; Store bx to restore later
    push cx                  ; Store cx to restore later
    push dx                  ; Store ds to restore later
    push si                  ; Store si to restore later

    mov si, sp               ; Load sp into si so it can be used as an offset
    mov dx, [si+10+4]        ; Load coordinates into dx (dh row) (dl col)
    mov al, dh               ; Load row into al
    mov cl, 160              ; Load row length into cl
    mul cl                   ; Multiply the row by the row length
    mov bx, ax               ; Move the adjusted row offset to bx

    xor ax, ax               ; Clear ax in preperation to calculate the column offset
    mov al, dl               ; Load column into al
    mov cl, 2                ; Load character size into cl
    mul cl                   ; Multiply the column by 2 (2 bytes per character)
    add bx, ax               ; Combine the total offset into bx

    mov ax, [si+10+2]        ; Load the character to print into ax
    mov byte ptr es:[bx], al ; Move the character to the proper offset in vram

    pop si                   ; Restore si to previous value
    pop dx                   ; Restore dx to previous value
    pop cx                   ; Restore cx to previous value
    pop bx                   ; Restore bx to previous value
    pop ax                   ; Restore ax to previous value
    ret
ENDP draw_row_col

print_string PROC
    ; TODO(Adin): Clean up
    mov si, [month_name_ptrs_v + 4]
    xor di, di
print_string_loop:
    mov al, byte ptr [si]
    cmp al, 0h
    jz print_string_done
    mov es:[di], al
    inc si
    add di, 2
    jmp print_string_loop
    
print_string_done:
    ret
ENDP print_string

draw_border PROC
    xor di, di              ; 0 vram index

    ; Draw top border
    insert_char_m 0C9h, 70h ; Upper-left corner

    mov cx, 78              ; stop one character short of the end for the top-right corner
top_loop:
    insert_char_m 0CDh, 70h ; horizontal double line
    loop top_loop

    insert_char_m 0BBh, 70h ; upper-right corner

    ; Draw Sides
    mov cx, 23              ; 23 middle lines
sides_loop:
    insert_char_m 0BAh, 70h ; vertical dobule line
    add di, 78*2            ; skip 78 characters between sides (2 bytes per character)
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
    mov ah, 2Ah
    int 21h

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

    draw_char_at_m 'S', 3, 27
    draw_char_at_m 'u', 3, 28
    
    draw_char_at_m 'M', 3, 31
    draw_char_at_m 'o', 3, 32

    draw_char_at_m 'T', 3, 35
    draw_char_at_m 'u', 3, 36

    draw_char_at_m 'W', 3, 39
    draw_char_at_m 'e', 3, 40
    
    draw_char_at_m 'T', 3, 43
    draw_char_at_m 'h', 3, 44
    
    draw_char_at_m 'F', 3, 47
    draw_char_at_m 'r', 3, 48
    
    draw_char_at_m 'S', 3, 51
    draw_char_at_m 'a', 3, 52

    mov dh, 5
    mov dl, 27

    mov cx, 42
days_loop:
    cmp dl, 55
    jne no_adjust
    add dh, 2
    mov dl, 27
no_adjust:
    push ax
    draw_char_at_dx_m '_'
    pop ax
    add dl, 1
    push ax
    draw_char_at_dx_m '_'
    pop ax
    add dl, 3
    loop days_loop

    call print_string

    ;mov si, ds:[month_name_ptrs_v + 2]
    ;call print_string
    ;add sp, 2

main_loop:
    mov ah, 00h ; Get keycode
    int 16h     ; Bios interrupt

    cmp al, 'q'
    jz  exit    ; If the key pressed was q, quit the program

    cmp al, 'Q'
    jz  exit    ; If the key pressed was Q, quit the program

    jmp main_loop

exit:
    ; Cleanup Code: Set the terminal back to default settings
    mov ax, 07h ; Change back to white text on black background
    push ax
    call clear_screen
    add sp, 2h

    mov ah, 01h     ; Set text-mode cursor shape
    mov cx, 0607h   ; Cursor from scanline 6 to 7 (basic underline)
    int 10h         ; Bios interrupt

    mov ah, 02h     ; Set cursor position
    mov bh, 00h     ; Page number 0
    mov dh, 00h     ; Row 0
    mov dl, 00h     ; Col 0
    int 10h         ; Bios interrupt

    mov ah, 00h     ; Terminate program
    int 21h         ; Software interrupt

ENDP main

END start