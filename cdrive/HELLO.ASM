.model tiny

.code
	org 100h

start:

	mov dx, offset hello		
	mov ah, 9
	int 21h

	mov ah, 4ch
	int 21h

	ret

hello db 'Hello, world.',13,10,'$'

	end start

