.org $000
JMP Start ; Указатель на начало программы
.org INT0addr
JMP EXT_INT0 ; Указатель на обработчик прерывания int0
.org INT1addr
JMP EXT_INT1 ; Указатель на обработчик прерывания int1

.def STEP = R28
.def VALUE1 = R29
.def VALUE2 = R30
.def VALUE3 = R31

.def LINE1 = R19
.def LINE2 = R20
.def LINE3 = R21
.def LINES_FIRST = R22 ; В регистре последние 3 бита - флаги использования линии в первый раз

.def LINE_COUNT = R23
; R23
; R24
; R25
; R26
; R27

JMP Start
; ---------- EEPROM --------------------------
EEPROM_read:
; Wait for completion of previous write
sbic EECR,EEWE ;skips the next command if eewe bit is clear
rjmp EEPROM_read
; Set up address (r18:r17) in address register eear
;It has two 8-bit registers EEARH and EEARL.
out EEARH, r26 ;EEARH contain last 9th bit of address
out EEARL, r25;EEARL contain first 8-bit of address
; Start eeprom read by writing EERE
sbi EECR,EERE
; Read data from data register
in STEP, EEDR
JMP Main_continue

EEPROM_write:
; Wait for completion of previous write
sbic EECR,EEWE
rjmp EEPROM_write
; Set up address (r18:r17) in address register
out EEARH, r26
out EEARL, r25
; Write data (r16) to data register
out EEDR, STEP
; Write logical one to EEMWE
sbi EECR,EEMWE
; Start eeprom write by setting EEWE
sbi EECR,EEWE
RET
; --------------------------------------------
; ---------- Прерывания ----------------------
EXT_INT0:
	PUSH R18
	IN R18, SREG
	PUSH R18
	
	MOV R17, STEP
	ANDI R17, 0b00001000
	BRNE STEP_NEGATIVE1 ; Переход, если значение шага отрицательное
	CPI STEP, 4
	BRNE STEP_LESS_4 ; Переход, если значение шага положительное, но меньше 4
	LDI STEP, 0b00001100 ; Присваиваем шагу -4 (В 4-ех разрядном прямом коде)
	JMP int0_next

STEP_NEGATIVE1: ; Значение шага отрицательное
	SUBI STEP, 1
	CPI STEP, 0b00001000
	BRNE int0_next
	LDI STEP, 0 ; Делаем из "отрицательного" нуля положительный
	JMP int0_next
	
STEP_LESS_4: ; Значение шага положительное, меньше 4
	INC STEP
	
int0_next: ; Сдвигаем значение шага, чтобы вывести на PD4-PD7
	MOV R16, STEP
	LSL R16
	LSL R16
	LSL R16
	LSL R16
	
	ANDI R16, 0b11110000
	OR R16, LINE_COUNT
	
	OUT PORTD, R16
	CALL EEPROM_write
	
	POP R18
	OUT SREG, R18
	POP R18
RETI
; --------------------------------------------
EXT_INT1:
	PUSH R18
	IN R18, SREG
	PUSH R18
	
	CPI LINE2, 25
	BREQ add_line2 ; Добавляем линию 2
	
	CPI LINE3, 25
	BREQ add_line3 ; Добавляем линию 3
	
	; Удаляем две последние линии
	LDI LINE2, 25
	LDI LINE3, 25
	LDI LINE_COUNT, 1
	JMP int1_next
	
add_line2:
	LDI LINE2, 0
	LDI LINE_COUNT, 2
	JMP int1_next
	
add_line3:
	LDI LINE3, 0
	LDI LINE_COUNT, 3

int1_next:
	MOV R16, STEP
	LSL R16
	LSL R16
	LSL R16
	LSL R16
	
	ANDI R16, 0b11110000
	OR R16, LINE_COUNT
	
	OUT PORTD, R16
	
	POP R18
	OUT SREG, R18
	POP R18
RETI
; --------------------------------------------

Change_line1:
	MOV R16, STEP
	MOV R17, STEP
	ANDI R17, 0b00001000
	BRNE step_neg1
	ADD R16, LINE1
	JMP divv1
	
step_neg1:
	MOV R16, LINE1
	MOV R17, STEP
	ANDI R17, 0b00000111
	SUB R16, R17
	

divv1: ; Находим остаток от деления суммы на 24
	CPI R16, 24
	BRLO change_value1
	SUBI R16, 24
	JMP divv1
	JMP change_value1
	
change_value1:
	MOV LINE1, R16
	LDI R16, 1 ; Необходимо данный бит сдвинуть на величину шага
			   ; в одном из трех регистров

	CPI LINE1, 0 ; Если равно, ничего сдвигать не нужно. Выводим первый бит в VALUE1
	BREQ line1_zero
	
	MOV R18, LINE1
	
	CPI R18, 8 ; Если значение меньше 8, меняем регистр 1
	BRSH greater8_line1

;--- Регистр VALUE1 --------------	
	MOV R17, R18
compare_7_line1: ; Выставляем бит в регистре от 0 до 7
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_7_line1
	OR VALUE1, R16 ; Меняем регистр для порта A
	JMP end_line1
;---------------------------------
	
;---------------------------------	
greater8_line1:
	CPI R18, 16 ; Если значение меньше 16, меняем регистр 2
	BRSH greater16_line1

;--- Регистр VALUE2 --------------	
	SUBI R18, 8	
	MOV R17, R18
compare_15_line1: ; Выставляем бит в регистре от 8 до 15
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_15_line1
	OR VALUE2, R16 ; Меняем регистр для порта B
	JMP end_line1
;---------------------------------

;--- Регистр VALUE3 --------------		
greater16_line1: ; меняем регистр 3
	SUBI R18, 16
	MOV R17, R18
compare_23_line1:
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_23_line1
	OR VALUE3, R16 ; Меняем регистр для порта С
	JMP end_line1
;---------------------------------
line1_zero:
ORI VALUE1, 0b00000001

end_line1:
JMP Compare_line2
; --------------------------------------------

Change_line2:
	MOV R16, STEP
	MOV R17, STEP
	ANDI R17, 0b00001000
	BRNE step_neg2
	ADD R16, LINE2
	JMP divv2
	
step_neg2:
	MOV R16, LINE2
	MOV R17, STEP
	ANDI R17, 0b00000111
	SUB R16, R17
	

divv2: ; Находим остаток от деления суммы на 24
	CPI R16, 24
	BRLO change_value2
	SUBI R16, 24
	JMP divv2
	JMP change_value2
	
change_value2:
	MOV LINE2, R16
	LDI R16, 1 ; Необходимо данный бит сдвинуть на величину шага
			   ; в одном из трех регистров

	CPI LINE2, 0 ; Если равно, ничего сдвигать не нужно. Выводим первый бит в VALUE1
	BREQ line2_zero
	
	MOV R18, LINE2
	
	CPI R18, 8 ; Если значение меньше 8, меняем регистр 1
	BRSH greater8_line2

;--- Регистр VALUE1 --------------	
	MOV R17, R18
compare_7_line2: ; Выставляем бит в регистре от 0 до 7
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_7_line2
	OR VALUE1, R16 ; Меняем регистр для порта A
	JMP end_line2
;---------------------------------
	
;---------------------------------	
greater8_line2:
	CPI R18, 16 ; Если значение меньше 16, меняем регистр 2
	BRSH greater16_line2

;--- Регистр VALUE2 --------------	
	SUBI R18, 8	
	MOV R17, R18
compare_15_line2: ; Выставляем бит в регистре от 8 до 15
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_15_line2
	OR VALUE2, R16 ; Меняем регистр для порта B
	JMP end_line2
;---------------------------------

;--- Регистр VALUE3 --------------		
greater16_line2: ; меняем регистр 3
	SUBI R18, 16
	MOV R17, R18
compare_23_line2:
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_23_line2
	OR VALUE3, R16 ; Меняем регистр для порта С
	JMP end_line2
;---------------------------------
line2_zero:
ORI VALUE1, 0b00000001

end_line2:
JMP Compare_line3
; --------------------------------------------

Change_line3:
	MOV R16, STEP
	MOV R17, STEP
	ANDI R17, 0b00001000
	BRNE step_neg3
	ADD R16, LINE3
	JMP divv3
	
step_neg3:
	MOV R16, LINE3
	MOV R17, STEP
	ANDI R17, 0b00000111
	SUB R16, R17
	

divv3: ; Находим остаток от деления суммы на 24
	CPI R16, 24
	BRLO change_value3
	SUBI R16, 24
	JMP divv3
	JMP change_value3
	
change_value3:
	MOV LINE3, R16
	LDI R16, 1 ; Необходимо данный бит сдвинуть на величину шага
			   ; в одном из трех регистров

	CPI LINE3, 0 ; Если равно, ничего сдвигать не нужно. Выводим первый бит в VALUE1
	BREQ line3_zero
	
	MOV R18, LINE3
	
	CPI R18, 8 ; Если значение меньше 8, меняем регистр 1
	BRSH greater8_line3

;--- Регистр VALUE1 --------------	
	MOV R17, R18
compare_7_line3: ; Выставляем бит в регистре от 0 до 7
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_7_line3
	OR VALUE1, R16 ; Меняем регистр для порта A
	JMP end_line3
;---------------------------------
	
;---------------------------------	
greater8_line3:
	CPI R18, 16 ; Если значение меньше 16, меняем регистр 2
	BRSH greater16_line3

;--- Регистр VALUE2 --------------	
	SUBI R18, 8	
	MOV R17, R18
compare_15_line3: ; Выставляем бит в регистре от 8 до 15
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_15_line3
	OR VALUE2, R16 ; Меняем регистр для порта B
	JMP end_line3
;---------------------------------

;--- Регистр VALUE3 --------------		
greater16_line3: ; меняем регистр 3
	SUBI R18, 16
	MOV R17, R18
compare_23_line3:
	LSL R16 ; Циклически сдвигаем бит на нужную позицию
	DEC R17
	BRNE compare_23_line3
	OR VALUE3, R16 ; Меняем регистр для порта С
	JMP end_line3
;---------------------------------
line3_zero:
ORI VALUE1, 0b00000001

end_line3:
JMP Ports_write
; --------------------------------------------

Start:
	LDI LINE_COUNT, 1
	LDI LINE1, 0
	LDI LINE2, 25
	LDI LINE3, 25
	LDI LINES_FIRST, 0b00000111
	
	SEI ; Включаем прерывания
	LDI R16, 0x0F
	OUT MCUCR, R16
	LDI R16, 0xC0
	OUT GICR, R16
	LDI R16, 0x01
	OUT PORTD, R16
	
	LDI R16, 0xFF
	OUT DDRA, R16
	OUT DDRB, R16
	OUT DDRC, R16
	LDI R16, 0xF3
	OUT DDRD, R16
	
	JMP EEPROM_read
	;LDI STEP, 0b00000100
Main_continue:	
	MOV R16, STEP
	LSL R16
	LSL R16
	LSL R16
	LSL R16
	
	ANDI R16, 0b11110000
	OR R16, LINE_COUNT
	
	OUT PORTD, R16
	
Cycle: ; --------------------------- Цикл ---------------------------
	LDI VALUE1, 0
	LDI VALUE2, 0
	LDI VALUE3, 0
	
	CPI LINE1, 25
	BREQ Compare_line2
	JMP Change_line1	
Compare_line2:

	CPI LINE2, 25
	BREQ Compare_line3
	JMP Change_line2
Compare_line3:

	CPI LINE3, 25
	BREQ Ports_write
	JMP Change_line3
	
	
Ports_write:	
	OUT PORTA, VALUE1
	OUT PORTB, VALUE2
	OUT PORTC, VALUE3
	
	LDI R18, 0xFF
	LDI R17, 0xFF
	LDI R16, 20
Delay_ms:
	DEC R18
	BRNE Delay_ms
	LDI R18, 0xFF
	DEC R17
	BRNE Delay_ms
	LDI R17, 0xFF
	DEC R16
	BRNE Delay_ms
	
	
	OUT PORTA, R18
	OUT PORTB, R18
	OUT PORTC, R18
	
	JMP Cycle
; -------------------------------------------------------------------