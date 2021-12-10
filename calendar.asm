.MODEL TINY

; Insert a character with a specified color at the current vram index (di)
; di is incremented accordingly
insert_char_m MACRO char, color
    mov byte ptr es:[di], char   ; move the character to vram
    inc di
    mov byte ptr es:[di], color  ; move the color to vram
    inc di
ENDM

; Push all registers to the stack when entering a procedure
pusha_m MACRO
    push ax
    push bx
    push cx
    push dx
    push si
    push di
ENDM

; Restore all registers from the stack when exiting a procedure
popa_m MACRO
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

ALL_REGS_OFF=12

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

; Destroys values in ax, bx, and cl
calculate_vram_offset_m MACRO
    mov al, dh               ; Load row into al
    mov cl, 160              ; Load row length into cl
    mul cl                   ; Multiply the row by the row length
    mov bx, ax               ; Move the adjusted row offset to bx

    xor ax, ax               ; Clear ax in preperation to calculate the column offset
    mov al, dl               ; Load column into al
    mov cl, 2                ; Load character size into cl
    mul cl                   ; Multiply the column by 2 (2 bytes per character)
    add bx, ax               ; Combine the total offset into bx
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
    insert_char_m 00h, al
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
    pusha_m                     ; Save registers to restore later

    mov si, sp                  ; Load sp into si so it can be used as an offset
    mov dx, [si+ALL_REGS_OFF+4] ; Load coordinates into dx (dh row) (dl col)

    calculate_vram_offset_m     ; Calculate the offset in vram from coordinates: offset is stored in bx

    mov ax, [si+12+2]           ; Load the character to print into ax
    mov byte ptr es:[bx], al    ; Move the character to the proper offset in vram

    popa_m                      ; Restore registers to previous values
    ret
ENDP draw_row_col

print_string PROC
    pusha_m                     ; Store registers to restore later

    mov bx, sp                  ; Use bx as stack offset
    mov si, [bx+ALL_REGS_OFF+2] ; Load string pointer into si
    mov dx, [bx+ALL_REGS_OFF+4] ; Load coordinates into dx

    calculate_vram_offset_m     ; Calculate the vram offset from coordinates and store in bx
    mov di, bx                  ; Move the vram offset to di

print_string_loop:
    lodsb                       ; Load current char from source string
    cmp al, 0h                  ; Check for null terminator
    jz print_string_done        ; Break if null terminator
    stosb                       ; Move the current char to vram
    inc di                      ; Skip over the format byte in vram
    jmp print_string_loop       ; Loop until done
    
print_string_done:
    popa_m                      ; Restore registers to previous values

    ret
ENDP print_string

print_year PROC
    pusha_m                     ; Store registers to restore later

    mov si, sp                  ; Move sp to si so it can be used as an offset
    mov dx, [si+ALL_REGS_OFF+4] ; Load the coordinates into dx
    calculate_vram_offset_m     ; Calculate the absolute vram offset specified by the coordinates
    mov di, bx                  ; Move the vram offset to di

    mov ax, [si+ALL_REGS_OFF+2] ; Load the year into ax
    mov bx, 1000                ; Move 1000 into bx to prepare for the upcoming division
    xor dx, dx                  ; Clear dx for the division (dividing by a word dvides DX:AX / r16)
    div bx                      ; Divide by 1000 to find the thousands place
    add ax, 30h                 ; Add 30h to the thousands place to get the ascii representation
    stosb                       ; Move the ascii thousands place to vram
    inc di                      ; Increment di to skip the format byte in vram
    
    mov ax, dx                  ; Move the remainder from the last division into ax (the year without the thousands place)
    mov bx, 100                 ; Move 100 into bx to prepare for the upcoming division
    xor dx, dx                  ; Clear dx for the division (dividing by a word dvides DX:AX / r16)
    div bx                      ; Divide by 100 to find the hundreds place
    add ax, 30h                 ; Add 30h to the hundreds place to get the ascii representation
    stosb                       ; Move the ascii hundreds place to vram
    inc di                      ; Increment di to skip the format byte in vram

    mov ax, dx                  ; Move the remainder from the last division into ax (the year without the thousands or hundreds place)
    mov bx, 10                  ; Move 10 into bx to prepare for the upcoming division
    xor dx, dx                  ; Clear dx for the division (dividing by a word dvides DX:AX / r16)
    div bx                      ; Divide by 10 to find the tens place
    add ax, 30h                 ; Add 30h to the tens place to get the ascii representation
    stosb                       ; Move the ascii tens place to vram
    inc di                      ; Increment di to skip the format byte in vram

    mov ax, dx                  ; Move the remainder from the last division into ax (ones place of the year)
    add ax, 30h                 ; Add 30h to the ones place to get the ascii representation
    stosb                       ; Move the ascii ones place to vram

    popa_m                      ; Restore registers to previous values
    ret
ENDP print_year

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

draw_static_elements PROC
    ; Draw the border
    call draw_border

    ; Draw the days of the week labels at their respective places
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

    ret
ENDP

draw_dynamic_elements PROC
    pusha_m        ; Store all registers to restore later

    ; Draw the days
    ; TODO(Adin): Document
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

    ; Clear the on-screen month
    mov di, 176h         ; Load the absolute offset of the month label in vram
    mov al, 0            ; Move an empty char into al

    mov cx, 9            ; Move 9 into cx as this is the maximum length of any month string
clear_mon_loop:
    stosb                ; Clear the current character in vram
    inc di               ; Increment di to skip the format byte
    loop clear_mon_loop  ; Loop back to clear_mon_loop
     
    ; Draw the current Month
    mov dh, 2                        ; Move the starting row into dh
    mov dl, 27                       ; Move the starting column into dl
    push dx                          ; Push the coordinates to the stack
    mov al, [curr_mon_v]             ; Load the current month index
    mov cl, 2                        ; Load 2 into cl
    mul cl                           ; Multiply by 2 to allign with word length pointers
    mov bx, ax                       ; Move month * 2 into bx so it can be as an offset
    mov dx, [month_name_ptrs_v + bx] ; Get the pointer to the current month's name from the name pointer array
    push dx                          ; Push the month name pointer to the stack
    call print_string                ; Print the string
    add sp, 4                        ; Discard the two parameters passed on the stack

    ; Draw the current year
    mov dh, 2                        ; Move the starting row into dh
    mov dl, 39                       ; Move the starting column into dl
    push dx                          ; Push the coordinates to the stack
    mov dx, [curr_yer_v]             ; Load the current year into dx
    push dx                          ; Push the current year to the stack
    call print_year                  ; Print the current year on screen
    add sp, 4                        ; Drop the 2 variables passed on the stack
    
    popa_m         ; Restore all registers to previous values
    ret
ENDP

main PROC
    mov ax, 0B800h
    mov es, ax           ; Store vram segment in es

    mov ah, 01h          ; Set text-mode cursor shape
    mov cx, 2607h        ; bit 5 of ch indicates invisible cursor, cursor from scanline 6 to 7
    int 10h              ; Bios interrupt

    mov ah, 2Ah          ; Get date
    int 21h              ; Dos interrupt
    sub dh, 1            ; Change the month to be 0 indexed
    mov [curr_mon_v], dh ; Store the current month in its corresponding variable
    mov [curr_yer_v], cx ; Store the current year in its corresponding variable

    ; Draw the background elements
    mov ax, 70h
    push ax
    call clear_screen
    add sp, 2

    call draw_static_elements  ; Draw all unchanging elements to the screen
    call draw_dynamic_elements ; Draw the initial month to the screen

main_loop:
    mov ah, 00h ; Get keycode
    int 16h     ; Bios interrupt

    ; 4b left
    cmp ah, 4Bh            ; Check if the current key code is a left arrow press
    jne not_left           ; If the keycode isn't left arrow keep checking
    dec [curr_mon_v]       ; Left current month
    cmp [curr_mon_v], 0FFh ; Check for month underflow
    jne update_screen      ; If no underflow, just update the screen
    inc [curr_mon_v]       ; If underflowed, change month back to january
    cmp [curr_yer_v], 1980 ; Check if underflowed and current year is min year
    jz update_screen       ; If underflowed and current year is min year, just update the screen
    dec [curr_yer_v]       ; If underflowed and current year isn't min year, decrement the year
    mov [curr_mon_v], 11   ; If underflowed and current year isn't min year, reset the month to december
    jmp update_screen      ; Update the screen after updating year and month

not_left:
    cmp ah, 4Dh            ; Check if the current key code is a right arrow press
    jne not_right          ; If the keycode isn't right arrow keep checking
    inc [curr_mon_v]       ; Increment current month
    cmp [curr_mon_v], 12   ; Check for month overflow
    jne update_screen      ; If no overflow, just update the screen
    dec [curr_mon_v]       ; If overflowed, change month back to december
    cmp [curr_yer_v], 2099 ; Check if overflowed and current year is max year
    jz update_screen       ; If overflowed and current year is max year, just update the screen
    inc [curr_yer_v]       ; If overflowed and current year isn't max year, increment the year
    mov [curr_mon_v], 0    ; If overflowed and current year isn't max year, reset the month to january
    jmp update_screen      ; Update the screen after updating year and month


not_right:
    cmp al, 'q'
    jz  exit    ; If the key pressed was q, quit the program

    cmp al, 'Q'
    jz  exit    ; If the key pressed was Q, quit the program

    jmp main_loop

update_screen:
    call draw_dynamic_elements ; Redraw all dynamic elements on the screen
    jmp main_loop              ; Loop

exit:
    ; Cleanup Code: Set the terminal back to default settings
    mov ax, 07h       ; Change back to white text on black background
    push ax
    call clear_screen ; Clear the screen to white text on black background
    add sp, 2h        ; Drop the color passed on the stack

    mov ah, 01h       ; Set text-mode cursor shape
    mov cx, 0607h     ; Cursor from scanline 6 to 7 (basic underline)
    int 10h           ; Bios interrupt

    mov ah, 02h       ; Set cursor position
    mov bh, 00h       ; Page number 0
    mov dh, 00h       ; Row 0
    mov dl, 00h       ; Col 0
    int 10h           ; Bios interrupt

    mov ah, 00h       ; Terminate program
    int 21h           ; Software interrupt

ENDP main

END start