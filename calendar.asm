.MODEL TINY

; insert_char_m
;
; Insert a character with a specified color at the current vram index (di)
; di is incremented accordingly
;
insert_char_m MACRO char, color
    mov byte ptr es:[di], char   ; move the character to vram
    inc di
    mov byte ptr es:[di], color  ; move the color to vram
    inc di
ENDM

; pusha_m
;
; Push all registers to the stack when entering a procedure
;
pusha_m MACRO
    push ax
    push bx
    push cx
    push dx
    push si
    push di
ENDM

; popa_m
;
; Restore all registers from the stack when exiting a procedure
;
popa_m MACRO
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
ENDM

ALL_REGS_OFF=12

; draw_char_at_m
;
; Draw char at (row, col)
; Top left is 0,0
;
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

; draw_char_at_dx_m
;
; Draw char at the coordinates stored in dx (dh->row, dl->col)
; Top left is 0,0
;
draw_char_at_dx_m MACRO char
    push si        ; Save si to restore later
    push bx        ; Save bx to restore later 

    push dx        ; Push the coordinates to the stack
    xor bh, bh     ; Clear dh so dx can store just the character to draw
    mov bl, char   ; Loaad the character into bl
    push bx        ; Push the character to the stack

    mov bx, [si+4] ; Restore bx to previous value
    mov si, [si+6] ; Restore si to previous value

    call draw_row_col

    add sp, 8      ; Drop the four values pushed to the stack: old si, old dx, coordinates, character
ENDM

; calculate_vram_offset_m
;
; Calculate the absolute vram offset from row, col coordinates stored in dx (dh->row, dl->col)
; The resulting offset is stored in bx
;
; Top left is 0,0
; NOTE: Destroys values in ax, bx, and cl
; 
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
; Name key:
;     c - constant
;     v - variable
;
;     s - strint
;     a - array
;
;     b - byte
;     w - word

; Month Names
jan_name_cs db "January",0
feb_name_cs db "Febuary",0
mar_name_cs db "March",0
apr_name_cs db "April",0
may_name_cs db "May",0
jun_name_cs db "June",0
jul_name_cs db "July",0
aug_name_cs db "August",0
sep_name_cs db "September",0
oct_name_cs db "October",0
nov_name_cs db "November",0
dec_name_cs db "December",0
; Array of month name pointers
month_name_ptrs_cwa dw offset jan_name_cs, offset feb_name_cs, offset mar_name_cs, offset apr_name_cs, offset may_name_cs, offset jun_name_cs, offset jul_name_cs, offset aug_name_cs, offset sep_name_cs, offset oct_name_cs, offset nov_name_cs, offset dec_name_cs

; Number of days in each month
month_lens_cba db 31,28,31,30,31,30,31,31,30,31,30,31
; Month key values used in get_day_of_first
month_keys_cba db 1,4,4,0,2,5,0,3,6,1,4,6

; Arrow keybinds help message line 1
help_arrows_1_cs db "Use left and right arrows", 0
; Arrow keybinds help message line 2
help_arrows_2_cs db "to navigate months", 0

; Q keybind help message
help_quit_cs db "Press q to quit", 0

; Current Month
curr_mon_vb db ?
; Current Year
curr_yer_vw dw ?

; Only used by draw_days
; Convenience variables to avoid loading these values multiple times
curr_day_vb db ?        ; The current day to draw
month_start_day_vb db ? ; The day of the week that the current month starts on
curr_month_len_vb db ?  ; The length of the current month

.CODE
ORG 100h     ; Code segment starts at 100h
start:
    jmp main ; Immedietely jump to main

; clear_screen
;
; Clear the screen to a specific color
; Parameters:
;     color - the color to clear the screen to
;             low byte of the word below the return address
;
clear_screen PROC
    push ax               ; Store ax to restore later

    xor di, di            ; 0 vram index
    mov si, sp            ; Move sp to si so it can be used as an offset
    mov ax, [si+4]        ; Load the color to clear the screen with into ax

    mov cx, 80*25         ; Loop over all characters in vram
clear_loop:
    insert_char_m 00h, al ; Insert a null character with the proper color
    loop clear_loop       ; Loop over the whole display

    pop ax                ; Restore ax
    ret
ENDP clear_screen

; draw_row_col
;
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

; print_string
;
; Print a null-terminated string at given coordinates
; Top left corner is at 0,0
;
; Parameters:
;     string - pointer to the first character in the string
;              word below return address on stack
;
;     row    - the row to draw the string at
;              high byte of the word below the string on stack
;
;     col    - the col to draw the string at
;              low byte of the word below the string on stack
;
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

; print_year
;
; Print a 4 digit (decimal) number at given coordinates
; Top left corner is at 0,0
;
; Parameters:
;     year - the number to print
;            word below return address on stack
;
;     row  - the row to draw the string at
;            high byte of the word below the year on stack
;
;     col  - the col to draw the string at
;            low byte of the word below the year on stack
;
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

; print_day
;
; Print a 2 digit (decimal) number at given coordinates
; Top left corner is at 0,0
;
; Parameters:
;     day - the number to print
;           low byte of the word below return address on stack
;
;     row - the row to draw the day at
;           high byte of the word below the day word on stack
;
;     col - the col to draw the day at
;           low byte of the word below the day word on stack
;
print_day PROC
    pusha_m                     ; Store registers on the stack to restore later

    mov si, sp                  ; Load sp into si so it can be used as an offset

    mov dx, [si+ALL_REGS_OFF+4] ; Load the starting coordinates into dx
    calculate_vram_offset_m     ; Calculate the absolute vram offset of the starting coordinates
    mov di, bx                  ; Move the vram offset into di

    mov ax, [si+ALL_REGS_OFF+2] ; Load the day into ax
    mov bl, 10                  ; Load 10 into bl to prepare for the upcoming division
    xor ah, ah                  ; Clear ah to prepare for the division (ax/bl)
    div bl                      ; Divide by 10 to split into ones (ah->remainder) and tens (al->quotient) places

    add al, 30h                 ; Add 30h to the tens place to get the ascii representation
    add ah, 30h                 ; Add 30h to the ones place to get the ascii representation
    stosb                       ; Move the ascii tens place to vram
    inc di                      ; Increment di to skip the format byte in vram

    mov al, ah                  ; Move the ascii ones place to al
    stosb                       ; Move the ascii ones place to vram

    popa_m                      ; Restore registers to previous values
    ret
ENDP

; draw_border
;
; Draw the calendar's border
; 
draw_border PROC
    pusha_m                 ; Store registers on the stack to restore later

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

    popa_m                  ; Restore registers to previous values
    ret
ENDP draw_border

; draw_static_elements
;
; Draw all the static elements to the screen
;
draw_static_elements PROC
    pusha_m          ; Save registers to the stack to restore later
    
    call draw_border ; Draw the border

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
    
    ; Print the help strings to the screen
    mov dh, 18                      ; Load row 18 into dh
    mov dl, 27                      ; Load column 27 into dl
    push dx                         ; Push coordinates to the stack
    mov cx, offset help_arrows_1_cs ; Load the pointer to help_arrows_1_cs into cx
    push cx                         ; Push the pointer to the stack
    call print_string               ; Print the string
    add sp, 4                       ; Drop the parameters pushed on the stack

    add dh, 1                       ; Move 1 row down
    push dx                         ; Push the coordinates to the stack
    mov cx, offset help_arrows_2_cs ; Load the pointer to help_arrows_2_cs into cx
    push cx                         ; Push the pointer to the stack
    call print_string               ; Print the string
    add sp, 4                       ; Drop the parameters pushed on the stack

    add dh, 2                       ; Move 2 rows down
    push dx                         ; Push the coordinates onto the stack
    mov cx, offset help_quit_cs     ; Load the pointer to help_quit_cs
    push cx                         ; Push the pointer to the stack
    call print_string               ; Print the string
    add sp, 4                       ; Drop the the parameters pushed on the stack

    popa_m          ; Restore registers from the stack
    ret
ENDP

; get_day_of_first
;
; Get the day of the week that the current month starts on (taken from curr_mon_vb and curr_yer_vw)
; Algorithm from https://cs.uwaterloo.ca/~alopez-o/math-faq/node73.html
; 
; Return Value:
;     the day of the week that the current month starts on
;     word below the return value on the stack
;
get_day_of_first PROC
    pusha_m                     ; Store registers on the stack to restore later

    mov ax, [curr_yer_vw]       ; Load the current year into ax
    mov bl, 100                 ; Move 100 into bl
    div bl                      ; Divide the year by 100 to find first two (al->quotient) and last two (ah->remainder) digits of the year
    mov dx, ax                  ; Save the split year in dx for later
    mov al, ah                  ; Move the last two digits of the year into al
    xor ah, ah                  ; Clear ah so ax just contains the last two digits of the year
    shr ax, 2                   ; "Divide the year by for, discarding any fraction"
    add ax, 1                   ; "Add the day of the month" (always looking for the first of the month so always add 1)

    xor bx, bx                  ; Clear bx to prepare to hold the current month (only one byte)
    mov bl, [curr_mon_vb]       ; Load the current month into bl
    xor cx, cx                  ; Clear cx to prepare to hold the current month's key
    mov cl, [month_keys_cba+bx] ; Load the current month's key into cl 
    add ax, cx                  ; "Add the month's key value"

    mov bx, [curr_yer_vw]       ; Load the current year into bx
    and bx, 0FFFCh              ; Calculate current year % 4 (2 least signifigant bits)
    jnz no_jan_feb_sub          ; If the remainder isn't 0 (not a leap year) don't check the month
    mov bl, [curr_mon_vb]       ; Load the current month into bl
    cmp bl, 2                   ; Compare bl to 2
    jge no_jan_feb_sub          ; If the current month is greater than or equal to 2 don't add 1 (not January or Febuary)
    sub al, 1                   ; "Subtract 1 for January or Febuary of a leap year"

no_jan_feb_sub:
    cmp dh, 19                  ; Compare dh to 19
    je no_2k_add                ; If the first two digits of the year aren't 19 don't add 6
    add ax, 6                   ; "For a Gregorian date, add 0 for 1900's, 6 for 2000's"

no_2k_add:
    mov dl, dh                  ; Move the last two digits of the year into dl
    xor dh, dh                  ; Clear dh so dx just contains the last two digits of the year
    add ax, dx                  ; "Add the last two digits of the year"
    
    mov bx, 7                   ; Load 7 into bx
    xor dx, dx                  ; Clear dx to prepare for the division (dx:ax / bx)
    sub ax, 1                   ; Adjust from 1=Sunday, 0=Saturday to 0=Sunday, 6=Saturday
    div bx                      ; "Divide by 7 and take the remainder"

    mov si, sp                  ; Move sp into si so it can be used as an offset
    mov [si+ALL_REGS_OFF+2], dx ; Store the return value on the stack so it can be retrieved by the calling function

    popa_m                      ; Restore registers to previous values
    ret
ENDP

; draw_days
;
; Draw the days of the month to the screen
;
draw_days PROC
    pusha_m                      ; Push registers to the stack to restore later

    mov [curr_day_vb], 0         ; Zero curr_day_vb

    sub sp, 2                    ; Allocate space on the stack for the return value
    call get_day_of_first        ; Get the day of the week that the first day of the month falls on
    pop bx                       ; Pop the return value into bx
    mov [month_start_day_vb], bl ; Store the day of the week in the convenience variable

    xor bh, bh                   ; Clear bh because bx is needed but only to store a byte length value
    mov bl, [curr_mon_vb]        ; Load the current month
    mov bl, [month_lens_cba+bx]  ; Load the current month's length (month_lens_cba[curr_month_v])
    mov [curr_month_len_vb], bl  ; Store the month length in the convenience variable

    mov cx, 42                   ; Loop 42 times for the day grid (6 rows of 7 days a week)
    mov dh, 5                    ; Start at row 5
    mov dl, 27                   ; Start at column 27
days_loop:
    cmp dl, 55                   ; Check if the column is past the end of the row
    jne no_adjust                ; If a newline isn't required don't readjust the coordinates
    add dh, 2                    ; Move down by 2 rows
    mov dl, 27                   ; Reset the column to the beginning of the row

no_adjust:
    cmp [curr_day_vb], 0         ; Check if the current day is 0
    jne day_is_num               ; If it's greater than 0 then print a numerical day
    mov bx, 42                   ; Move the maximum number of days into bx
    sub bx, cx                   ; Subtract the current loop count to find the index of the day being drawn
    cmp bl, [month_start_day_vb] ; Compare the current day index to the starting day of the week for the month
    jne no_start_yet             ; If the current day index isn't equal to the starting day of the week don't start printing numbers
    mov [curr_day_vb], 1         ; If this is the day of the week that the month starts on set the current day to 1
    jmp day_is_num               ; Go print the numerical day

no_start_yet:
    draw_char_at_dx_m '_'        ; Draw the first half of a non-numerical day
    inc dl                       ; Skip the format byte in vram
    draw_char_at_dx_m '_'        ; Draw the second half of a non-numerical day
    add dl, 3                    ; Skip the format byte and spacing betwen days
    jmp done_printing            ; Skip drawing a numerical day

day_is_num:
    push dx                      ; Push the current coordinates onto the stack
    xor bh, bh                   ; Clear bh because bx is needed but only to store a byte length value
    mov bl, [curr_day_vb]        ; Load the current day into bl
    push bx                      ; Push the current day onto the stack
    call print_day               ; Print the current numerical day
    add sp, 4                    ; Drop the two paremeters passed on the stack
    add dl, 4                    ; Move the coordinates onto the location of the next day to draw
    inc [curr_day_vb]            ; Move the current day onto the next
    
    mov bl, [curr_month_len_vb]  ; Load the length of the current month into bl
    inc bl                       ; Add 1 to find 1 past the length of the current month
    cmp bl, [curr_day_vb]        ; Compare the next day to print (current day after incrementing post printing) to the length of the month + 1
    jne done_printing            ; If the next day to print isn't off the end of the month, just finish printing
    mov [curr_day_vb], 0         ; If the next day to print would be after the end of the month set curr_day_vb to 0 so that the rest of the days to print will be non numerical
                                 ; NOTE: Setting curr_day_vb to 0 here will never start printing numerical days again because when checking for the first day of the week equality is checked not greater to or equal

done_printing:
    loop days_loop               ; Loop over the days to print

    popa_m                       ; Restore registers to previous values
    ret
ENDP

; draw_dynamic_elements
;
; Draw all dynamic elements to the screen
;
draw_dynamic_elements PROC
    pusha_m                            ; Store all registers to restore later

    ; Clear the on-screen month
    mov di, 176h                       ; Load the absolute offset of the month label in vram
    mov al, 0                          ; Move an empty char into al

    mov cx, 9                          ; Move 9 into cx as this is the maximum length of any month string
clear_mon_loop:
    stosb                              ; Clear the current character in vram
    inc di                             ; Increment di to skip the format byte
    loop clear_mon_loop                ; Loop back to clear_mon_loop
     
    ; Draw the current Month
    mov dh, 2                          ; Move the starting row into dh
    mov dl, 27                         ; Move the starting column into dl
    push dx                            ; Push the coordinates to the stack
    mov al, [curr_mon_vb]              ; Load the current month index
    mov cl, 2                          ; Load 2 into cl
    mul cl                             ; Multiply by 2 to allign with word length pointers
    mov bx, ax                         ; Move month * 2 into bx so it can be as an offset
    mov dx, [month_name_ptrs_cwa + bx] ; Get the pointer to the current month's name from the name pointer array
    push dx                            ; Push the month name pointer to the stack
    call print_string                  ; Print the string
    add sp, 4                          ; Discard the two parameters passed on the stack

    ; Draw the current year
    mov dh, 2                          ; Move the starting row into dh
    mov dl, 39                         ; Move the starting column into dl
    push dx                            ; Push the coordinates to the stack
    mov dx, [curr_yer_vw]              ; Load the current year into dx
    push dx                            ; Push the current year to the stack
    call print_year                    ; Print the current year on screen
    add sp, 4                          ; Drop the 2 variables passed on the stack

    ; Draw the days of the month
    call draw_days

    popa_m                             ; Restore all registers to previous values
    ret
ENDP

; main
;
; main procedure that contains setup, main loop, and cleanup code
;
main PROC
    mov ax, 0B800h
    mov es, ax            ; Store vram segment in es

    mov ah, 01h           ; Set text-mode cursor shape
    mov cx, 2607h         ; bit 5 of ch indicates invisible cursor, cursor from scanline 6 to 7
    int 10h               ; Bios interrupt

    mov ah, 2Ah           ; Get date
    int 21h               ; Dos interrupt
    sub dh, 1             ; Change the month to be 0 indexed
    mov [curr_mon_vb], dh ; Store the current month in its corresponding variable
    mov [curr_yer_vw], cx ; Store the current year in its corresponding variable

    ; Draw the background elements
    mov ax, 70h
    push ax
    call clear_screen
    add sp, 2

    call draw_static_elements  ; Draw all unchanging elements to the screen
    call draw_dynamic_elements ; Draw the initial month to the screen

main_loop:
    mov ah, 00h             ; Get keycode
    int 16h                 ; Bios interrupt

    ; 4b left
    cmp ah, 4Bh             ; Check if the current key code is a left arrow press
    jne not_left            ; If the keycode isn't left arrow keep checking
    dec [curr_mon_vb]       ; Left current month
    cmp [curr_mon_vb], 0FFh ; Check for month underflow
    jne update_screen       ; If no underflow, just update the screen
    inc [curr_mon_vb]       ; If underflowed, change month back to january
    cmp [curr_yer_vw], 1980 ; Check if underflowed and current year is min year
    jz update_screen        ; If underflowed and current year is min year, just update the screen
    dec [curr_yer_vw]       ; If underflowed and current year isn't min year, decrement the year
    mov [curr_mon_vb], 11   ; If underflowed and current year isn't min year, reset the month to december
    jmp update_screen       ; Update the screen after updating year and month

not_left:
    cmp ah, 4Dh             ; Check if the current key code is a right arrow press
    jne not_right           ; If the keycode isn't right arrow keep checking
    inc [curr_mon_vb]       ; Increment current month
    cmp [curr_mon_vb], 12   ; Check for month overflow
    jne update_screen       ; If no overflow, just update the screen
    dec [curr_mon_vb]       ; If overflowed, change month back to december
    cmp [curr_yer_vw], 2099 ; Check if overflowed and current year is max year
    jz update_screen        ; If overflowed and current year is max year, just update the screen
    inc [curr_yer_vw]       ; If overflowed and current year isn't max year, increment the year
    mov [curr_mon_vb], 0    ; If overflowed and current year isn't max year, reset the month to january
    jmp update_screen       ; Update the screen after updating year and month


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