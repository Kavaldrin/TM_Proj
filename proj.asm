.PORT uart0_int_mask, 0x62
.PORT uart0_status, 0x61
.PORT uart0_tx, 0x60
.PORT uart0_rx, 0x60
.PORT int_status, 0xE0
.PORT int_mask, 0xE1
.PORT lcd_value, 0x30
.PORT lcd_control, 0x31
.PORT uart1_int_mask, 0x6A
.PORT uart1_status, 0x69
.PORT uart1_tx, 0x68
.PORT uart1_rx, 0x68
.PORT leds, 0
.PORT ram_page, 0xF0

.CONST incoming_string_page, 1
.CONST coordinate_string_page, 2
.CONST is_storing_enabled, 0b00000001
.CONST LF_ascii_code, 0x0A
.CONST numeric_record_len, 9
.CONST time_record_pos, 6
.CONST latitude_record_pos, time_record_pos + numeric_record_len + 2
.CONST latitude_indicator_pos, latitude_record_pos + numeric_record_len + 1
.CONST longitude_record_pos, latitude_indicator_pos + 3
.CONST longitude_indicator_pos, longitude_record_pos + numeric_record_len + 1
.CONST time_record_len, 6


.REG sF, control
.REG sE, value
.REG sD, char_to_write
.REG sC, coursor_pos
.REG sB, current_pos
.REG sA, recv_char
.REG s9, flow_control_flags 
.REG s8, current_ram_pos

.DSEG
	mesg_id: .DB "GPGGA"

.CSEG 0x3FF
	JUMP handle_irq

.MACRO nop
	LOAD s0, s0
	LOAD s0, s0
.ENDM

.CSEG

LOAD control, 0
OUT control, lcd_control
main:
	CALL init_lcd
	CALL init_irq
	JUMP loop

handle_irq:
	CALL recv_and_send
	LOAD s0, 0
	OUT s0, int_status
	RETI

recv_and_send:
	CALL recv
	CALL send
	RET

recv:
	IN recv_char, uart1_rx
	
	TEST flow_control_flags, is_storing_enabled
	CALL NZ, store_incoming_char
	
	TEST flow_control_flags, is_storing_enabled
	JUMP NZ, end_recv_func
	
	COMP recv_char, '$'
	JUMP NZ, end_recv_func
	OR flow_control_flags, is_storing_enabled
	LOAD current_ram_pos, 0
	end_recv_func:
		

	RET

store_incoming_char:
	LOAD s5, incoming_string_page
	OUT s5, ram_page
	STORE recv_char, current_ram_pos
	ADD current_ram_pos, 1

	COMP recv_char, LF_ascii_code
	JUMP NZ, end_store_incoming_char_func

	XOR flow_control_flags, is_storing_enabled
	CALL parse_string

	end_store_incoming_char_func:
	
	RET

parse_string:
	LOAD s5, 0
	
	loop_parse_string:
		LOAD s6, incoming_string_page
		OUT s6, ram_page
		FETCH s6, s5
		
		LOAD s7, 0
		OUT s7, ram_page
		LOAD s7, mesg_id
		ADD s7, s5
		FETCH s0, s7
	
		COMP s0, s6
		JUMP NZ, end_parse_string_func
		
		ADD s5, 1
		COMP s5, 5
		JUMP NZ, loop_parse_string
	CALL extract_data_from_string
	end_parse_string_func:
	RET

extract_data_from_string:
	

	LOAD s5, time_record_pos
	LOAD s6, 0
	LOAD s1, 0
	
; time
	loop_extract_time_from_string:
	LOAD s7, incoming_string_page
	OUT  s7, ram_page
	FETCH s0, s5
	
	LOAD s7, coordinate_string_page
	OUT s7, ram_page
	STORE s0,  s6
	
	ADD 	s6, 1
	ADD s1, 1
	ADD s5, 1

	COMP s1, time_record_len
	JUMP NZ, loop_extract_time_from_string

;latitude

	LOAD s5, latitude_record_pos
	LOAD s1, 0

	loop_extract_latitude_from_string:
	LOAD s7, incoming_string_page
	OUT  s7, ram_page
	FETCH s0, s5
	
	LOAD s7, coordinate_string_page
	OUT s7, ram_page
	STORE s0,  s6
	
	ADD 	s6, 1
	ADD s5, 1
	ADD s1, 1
	COMP s1, numeric_record_len

	JUMP NZ, loop_extract_latitude_from_string

;latitude indicator
	LOAD s5, latitude_indicator_pos
	
	LOAD s7, incoming_string_page
	OUT  s7, ram_page
	FETCH s0, s5
	
	LOAD s7, coordinate_string_page
	OUT s7, ram_page
	STORE s0,  s6

	ADD 	s6, 1

;longitude 

	LOAD s5, longitude_record_pos
	LOAD s1, 0

	loop_extract_longitude_from_string:
	LOAD s7, incoming_string_page
	OUT  s7, ram_page
	FETCH s0, s5
	
	LOAD s7, coordinate_string_page
	OUT s7, ram_page
	STORE s0,  s6
	
	ADD 	s6, 1
	ADD s5, 1	
	ADD s1, 1
	COMP s1, numeric_record_len

	JUMP NZ, loop_extract_longitude_from_string

;longitude indicator
	LOAD s5, longitude_indicator_pos

	LOAD s7, incoming_string_page
	OUT  s7, ram_page
	FETCH s0, s5
	
	LOAD s7, coordinate_string_page
	OUT s7, ram_page
	STORE s0,  s6

	RET

send:
	OUT recv_char, uart0_tx
	RET

init_irq:
	EINT
	LOAD s0, 0b00001000
	OUT s0, int_mask
	LOAD s0, 0b00010000
	OUT s0, uart1_int_mask
	RET

init_lcd:
	LOAD s4, 4
	CALL reset_seq
		
	LOAD control, 0x1
	LOAD value, 0x06
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	CALL opoznij_5m

	LOAD control, 0x1
	LOAD value, 0x0E
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	CALL opoznij_5m

	LOAD control, 0x1
	LOAD value, 0x01
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	CALL opoznij_5m

	LOAD control, 0x1
	LOAD value, 0x80
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	CALL opoznij_5m

	LOAD current_pos, 0x0

	RET

set_coursor:
	LOAD control, 0x1
	LOAD value, coursor_pos
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	CALL opoznij_40u
	RET

reset_seq:
	CALL send_reset
	CALL opoznij_5m
	SUB s4, 1
	JUMP NZ, reset_seq
	RET

send_reset:
	LOAD control, 0x1
	LOAD value, 0x38
	OUT value, lcd_value
	OUT control, lcd_control
	_nop
	LOAD control, 0x0
	OUT control, lcd_control
	RET

opoznij_1u: LOAD s0,23
czekaj_1u: SUB s0,1
JUMP NZ,czekaj_1u
LOAD s0,s0 ;NOP
LOAD s0,s0 ;NOP
RET

opoznij_40u: LOAD s1,38
czekaj_40u: CALL opoznij_1u
SUB s1,1
JUMP NZ,czekaj_40u
RET
	
opoznij_1m: LOAD s2,25
czekaj_1m: CALL opoznij_40u
SUB s2,1
JUMP NZ,czekaj_1m
RET

opoznij_5m: LOAD s3,5
czekaj_5m: CALL opoznij_1m
SUB s3,1
JUMP NZ,czekaj_1m
RET

loop:
	JUMP loop