EOFLine EQU '$'                                                  ; определение символьной константы
                                                                 ; $ - "конец строки"
TESTPC SEGMENT                                                   ; определение начала сегмента
	   ASSUME CS:TESTPC, DS:TESTPC, ES:NOTHING, SS:NOTHING    
	   ORG 100H                                              ; смещение
START: JMP BEGIN                                                 ; переход на метку
;ДАННЫЕ
;--------------------------------------------------------------------------------------------
endl                     db ' ',0DH,0AH,'$'                      ; 0DH - возврат каретки, 0AH - перевод строки
seg_address_inaccessible db 'Segment address of inaccessible memory:     ',0DH,0AH,EOFLine
seg_address_environment  db 'Segment address of the environment:     ',0DH,0AH,EOFLine
contents_environment     db 'The contents of the environment area: ',0DH,0AH,EOFLine
loadable_module_path     db 'Loadable module path: ',0DH,0AH,EOFLine
command_line_tail        db 'Command-line tail:',EOFLine
command_empty            db ' Empty',0DH,0AH,EOFLine
;ПРОЦЕДУРЫ
;--------------------------------------------------------------------------------------------
TETR_TO_HEX PROC near                                            ; из двоичной в шестнадцатеричную сс
	and  AL,0Fh                                              ; PROC near - вызывается в том же сегменте, в котором определена
	cmp  AL,09
	jbe  NEXT
	add  AL,07
NEXT:   add AL,30h
	ret
TETR_TO_HEX ENDP

BYTE_TO_HEX PROC near                                            ; байтовое число в шестнадцатеричную сс
	push CX
	mov  AH,AL
	call TETR_TO_HEX
	xchg AL,AH
	mov  CL,4
	shr  AL,CL
	call TETR_TO_HEX
	pop  CX
	ret
BYTE_TO_HEX ENDP
 
WRD_TO_HEX PROC near                                             ; шестнадцатибитовое число в шестнадцатеричную сс
	push BX
	mov  BH,AH
	call BYTE_TO_HEX
	mov  [DI],AH
	dec  DI
	mov  [DI],AL
	dec  DI
	mov  AL,BH
	call BYTE_TO_HEX
	mov  [DI],AH
	dec  DI
	mov  [DI],AL
	pop  BX
	ret
WRD_TO_HEX ENDP

BYTE_TO_DEC PROC near                                            ; байтовое число в десятичную сс
	push CX
	push DX
	xor  AH,AH
	xor  DX,DX
	mov  CX,10
loop_bd: div CX
	or   DL,30h
	mov  [SI],DL
	dec  SI
	xor  DX,DX
	cmp  AX,10
	jae  loop_bd
	cmp  AL,00h
	je   end_l
	or   AL,30h
	mov  [SI],AL
end_l:  pop DX
	pop  CX
	ret
BYTE_TO_DEC ENDP
;--------------------------------------------------------------------------------------------
LINE_OUTPUT PROC near                                            ; вывод строки
        push AX
        mov  AH, 09h
	int  21H
	pop  AX
	ret
LINE_OUTPUT ENDP

SEGMENT_INACCESSIBLE PROC near                                   ; получение сегментного адреса недоступной памяти
        push AX
	push DI
	mov  AX, DS:[02h]                                        ; DS - сегментный регистр, указывает на PSP
	mov  DI, OFFSET seg_address_inaccessible                 ; помещаем в DI смещение строки
	add  DI, 43
	call WRD_TO_HEX
	pop  DI
	pop  AX
	ret
SEGMENT_INACCESSIBLE ENDP

SEGMENT_ENVIRONMENT PROC near                                    ; получение сегментного адреса среды
        push AX
	push DI
	mov  AX, DS:[2Ch]
	mov  DI, OFFSET seg_address_environment
	add  DI, 39
	call WRD_TO_HEX
	pop  DI
	pop  AX
	ret
SEGMENT_ENVIRONMENT ENDP

ENVIRONMENT PROC near                                            ; получение содержимого области среды
        push AX
	push DX
	push DS
	push ES
	mov  DX, OFFSET contents_environment
	call LINE_OUTPUT
	mov  AH, 02h
	mov  ES, DS:[2Ch]                                        ; записываем в ES адрес области среды
	xor  SI, SI                                              ; обнуляем регистр SI
content:
        mov  DL, ES:[SI]
	int  21h
	cmp  DL, 00h
	je   content_end                                         ; переход, если равны
	inc  SI                                                  ; команда, которая увеличивает число на единицу
	jmp  content                                             ; безусловный переход
content_end:
        mov  DX, OFFSET endl
	call LINE_OUTPUT
	inc  SI
	mov  DL, ES:[SI]
	cmp  DL, 00h
	jne  content                                             ; переход, если не равны
	mov  DX, OFFSET endl
	call LINE_OUTPUT
	pop  ES
	pop  DS
	pop  DX
	pop  AX
	ret
ENVIRONMENT ENDP

PATH PROC near                                                   ; получение пути загружаемого модуля
        push AX
	push DX
	push DS
	push ES
	mov  DX, OFFSET loadable_module_path
        call LINE_OUTPUT
        add  SI, 04h
        mov  AH, 02h
        mov  ES, DS:[2Ch]
way:
        mov  DL, ES:[SI]
        cmp  DL, 00h
        je   way_end
        int  21h
        inc  SI
        jmp  way
way_end:
        pop  ES
        pop  DS
        pop  DX
        pop  AX	
        ret
PATH ENDP

TAIL PROC near                                                   ; получение хвоста командной строки
        push AX
	push CX
	push DX
	push SI
        mov  DX, offset command_line_tail
	call LINE_OUTPUT
	mov  CL, DS:[80h]                                        ; 80h - число символов в хвосте командной строки
	cmp  CL, 00h
	je   empty
	mov  SI, 81h                                             ; 81h - последовательность символов после загружаемого модуля
	mov  AH, 02h
command:
	mov  DL, DS:[SI]
	int  21h
	inc  SI
	loop command                                             ; цикл
	mov  DX, offset endl
	call LINE_OUTPUT
	jmp  end_tail
empty:
        mov  AL, 00h
	mov  [DI], AL
	mov  DX, OFFSET command_empty
	call LINE_OUTPUT
end_tail:
	pop  SI
	pop  DX
	pop  CX
	pop  AX
	ret
TAIL ENDP
;--------------------------------------------------------------------------------------------
BEGIN:
        call SEGMENT_INACCESSIBLE
        mov  DX, OFFSET seg_address_inaccessible
        call LINE_OUTPUT
        call SEGMENT_ENVIRONMENT
        mov  DX, OFFSET seg_address_environment
        call LINE_OUTPUT
        call TAIL
        mov  DX, OFFSET endl
        call LINE_OUTPUT
        call ENVIRONMENT
        call PATH
;ВЫХОД ИЗ DOS
;--------------------------------------------------------------------------------------------
        xor  AL,AL                                               ; обнуление регистра
        mov  AH,4CH
        int  21h
TESTPC  ENDS
        END START                                                ; конец модуля, START - точка входа
