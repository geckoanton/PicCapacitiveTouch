INCLUDE <p12f675.inc>

;configuration registers

__CONFIG    _HS_OSC & _WDT_OFF & _PWRTE_OFF & _MCLRE_ON & _BOREN_ON & _CP_OFF & _CPD_OFF

;define register addreses
    
;holds calibration for charge time
CA0 equ h'21'
CA1 equ h'22'
 
;shadow register to gpio
SHADGPIO equ h'23'
 
;gets set by CHARGE_TIME section (count)
COUNT0 equ h'24'
COUNT1 equ h'25'
 
;delay registers
DELAY0 equ h'26'
DELAY1 equ h'27'
DELAY2 equ h'30'
 
;holds average calbration sum
CA0_SUM equ h'28'
CA1_SUM equ h'29'
CA2_SUM equ h'2a'
 
;sets how many samples calibrate takes
CA_SAM equ h'2b'
CA_SAM_INI equ h'2c'
 
;holds differance between count and ca
DIF_CA0 equ h'2d'
DIF_CA1 equ h'2e'
 
;differance flag register
DIF_FLAG equ h'2f'
    
RES_VECT  CODE    0x0000            
    GOTO    START                   

MAIN_PROG CODE                      

START
;setup--------------------------------------------------------------------------
    ;move to bank 0
    bcf STATUS, 5
    clrf GPIO
    ;04 sets up comparator with cvref non inverting input
    movlw h'04'
    movwf CMCON
    
    ;move to bank 1
    bsf STATUS, 5
    ;clear ansel and trisio (all output pins) except for gpio1
    clrf ANSEL
    movlw h'2'
    movwf TRISIO
    ;initialize timer0
    bsf OPTION_REG, 3
    bcf OPTION_REG, 5
    ;initialize comparator cvref
    movlw b'10001111'
    movwf VRCON
    
    ;move to bank 0
    bcf STATUS, 5
    ;clear registers in use
    clrf SHADGPIO
    clrf CA0
    clrf CA1
    clrf COUNT0
    clrf COUNT1
    clrf DELAY0
    clrf DELAY1
    clrf DELAY2
    clrf CA0_SUM
    clrf CA1_SUM
    clrf CA2_SUM
    clrf CA_SAM
    clrf CA_SAM_INI
    clrf DIF_CA0
    clrf DIF_CA1
    clrf DIF_FLAG
    
    ;goto main code
    goto MAIN
    
;-------------------------------------------------------------------------------
  
;update charge time subroutine--------------------------------------------------
CHARGE_TIME
    ;clear COUNT0 and COUNT1
    clrf COUNT0
    clrf COUNT1
    ;set GP0 to low (discharge capacitance)
    bcf SHADGPIO, 0
    movf SHADGPIO, 0
    movwf GPIO
    
    ;delay to let capacitance discharge
    movlw h'ff'
    movwf DELAY0
    movlw h'14'
    movwf DELAY1
    
    ;loop a couple of milliseconds
    call DELAY_MS
    
    ;clear timer overflow flag
    bcf INTCON, 2
    
OVERFLOW
    ;set timer0 to 0
    clrf TMR0
    
    ;clear timer overflow flag
    bcf INTCON, 2
    
    ;set gp0 to high (start charging capacitance)
    bsf SHADGPIO, 0
    movf SHADGPIO, 0
    movwf GPIO
    
    ;update count0 with tmr0 all the time its charging
UPDATE_CHARGE_TIME
    movf TMR0, 0
    movwf COUNT0
    
    ;add 1 to count1 when overflowed and clear t0if
    btfsc INTCON, 2
    call INCREMENT_COUNT1
    
    ;check if comparator has gone low
    btfsc CMCON, 6
    goto UPDATE_CHARGE_TIME
    
    return
    
;-------------------------------------------------------------------------------
    
;calibration subroutine---------------------------------------------------------
CALIBRATE
    ;set ca_sam to 5 calibration samples, cant be more than 255
    movlw h'5'
    movwf CA_SAM
    movwf CA_SAM_INI
    
    clrf CA0_SUM
    clrf CA1_SUM
    clrf CA2_SUM
    
    clrf CA0
    clrf CA1
    
SAMPLE
    ;update count registers
    call CHARGE_TIME
    
    ;add ca0_sum and count0, store in ca0_sum
    movf COUNT0, 0
    addwf CA0_SUM, 1
    
    ;check if a carry has occured
    btfsc STATUS, 0
    call ADD_CA1_CA2
    
    ;add count1 to ca1_sum
    movf COUNT1, 0
    addwf CA1_SUM, 1
    
    btfsc STATUS, 0
    incf CA2_SUM, 1
    
    ;check if ca_sam has decreased to 0
    decfsz CA_SAM
    goto SAMPLE
    
DIVIDE
    ;check if ca2_sum, ca1_sum is zero and ca0 - ca_sam_ini has a borrow
    
    ;check if ca2 is 0
    movlw h'1'
    subwf CA2_SUM, 0
    
    ;move to subtract directly if its not zero
    btfsc STATUS, 0
    goto SUBTRACT
    
    ;otherwise check if ca1 is 0
    movlw h'1'
    subwf CA1_SUM, 0
    
    ;move to subtract directly if its not zero
    btfsc STATUS, 0
    goto SUBTRACT
    
    ;otherwise check if ca0 is smaller than ca_sam_ini
    movf CA_SAM_INI, 0
    subwf CA0_SUM, 0
    
    ;if ca0 is smaller than ca_sam_ini skip to continue
    btfss STATUS, 0
    return
    
SUBTRACT
    ;divide ca_sum by ca_sam_ini
    movf CA_SAM_INI, 0
    subwf CA0_SUM, 1
    
    ;check if borrow has occured
    btfss STATUS, 0
    call SUB_CA1_CA2_SUM
    
    ;add 1 to ca0 ca1 when subtraction went through
    movlw h'1'
    addwf CA0, 1
    
    ;check if ca0 has a carry
    btfsc STATUS, 0
    incf CA1, 1
    
    goto DIVIDE
    
    return
    
;-------------------------------------------------------------------------------
    
;delay subroutine---------------------------------------------------------------
DELAY_MS
LOOP
    decfsz DELAY0, 1
    goto LOOP
    decfsz DELAY1, 1
    goto LOOP
    
    return
;-------------------------------------------------------------------------------
    
;other instructions-------------------------------------------------------------
INCREMENT_COUNT1
    incf COUNT1, 1
    bcf INTCON, 2
    return
    
ADD_CA1_CA2
    incf CA1_SUM, 1
    ;check if ca1_sum has overflowed
    btfsc STATUS, 2
    incf CA2_SUM, 1
    return
    
SUB_CA1_CA2_SUM
    ;set w register to 1
    movlw h'1'
    ;subtract ca1 with 1 (w register)
    subwf CA1_SUM, 1
    
    ;check if ca1 has a borrow
    btfsc STATUS, 0
    return
    
    ;if continued here ca1 has a borrow
    
    ;subtract ca2 with 1 aswell then
    subwf CA2_SUM, 1
    
    return
    
ABB
    ;count is bigger than ca
    bsf DIF_FLAG, 1
    goto AFTER_SUB
    
BBA
    ;ca is bigger than count
    bcf DIF_FLAG, 1
    goto AFTER_SUB
    
DEC_DIF_CA1
    ;decrement DIF_CA1
    movlw h'1'
    subwf DIF_CA1
    
    ;check if borrow occured
    btfss STATUS, 0
    goto ABB
    
    return
    
TOGGLE_IO
    ;check if gp2 is off/on
    btfss GPIO, 2
    goto SET_IO
    
    ;otherwise clear gp2
    bcf SHADGPIO, 2
    movf SHADGPIO, 0
    movwf GPIO
    
    ;skip set_io
    goto WAIT
    
SET_IO
    ;turn gp2 on
    bsf SHADGPIO, 2
    movf SHADGPIO, 0
    movwf GPIO
    
WAIT
    ;set delay values
    movlw h'ff'
    movwf DELAY0
    movlw h'ff'
    movwf DELAY1
    movlw h'c'
    movwf DELAY2
    
WAIT2
    ;delay around 1 sec at 10 MHz oscillator frequency
    decfsz DELAY0, 1
    goto WAIT2
    decfsz DELAY1, 1
    goto WAIT2
    decfsz DELAY2, 1
    goto WAIT2
    
    
    return
    
;-------------------------------------------------------------------------------
    
;main code----------------------------------------------------------------------
MAIN
    ;set up calibration values
    call CALIBRATE
    
    ;add a constant to the calibrated value
    movlw h'a'
    addwf CA0, 1
    
    ;check if carry occured
    btfsc STATUS, 0
    incf CA1, 1
  
UPDATE
    ;set count values
    call CHARGE_TIME
    
    ;subtract count1 from ca1
    movf COUNT1, 0
    subwf CA1, 0
    
    ;check if COUNT1 is bigger than CA1
    btfss STATUS, 0
    goto ABB
    
    ;move result from subtraction to DIF_CA1
    movwf DIF_CA1
    
    ;subtract count0 from ca0
    movf COUNT0, 0
    subwf CA0, 0
    
    ;set result to DIF_CA0
    movwf DIF_CA0
    
    ;check if borrow occured
    btfss STATUS, 0
    call DEC_DIF_CA1
    
    ;check if DIF_CA is 0
    ;check dif_ca0
    movf DIF_CA0, 1
    
    btfss STATUS, 2
    goto CON_BBA
    
    ;check dif_ca1
    movf DIF_CA1, 1
    
    btfss STATUS, 2
    goto CON_BBA
    
    ;dif_ca is zero (count equals ca)
    bsf DIF_FLAG, 0
    goto AFTER_SUB
    
CON_BBA
    ;otherwise ca is bigger than count
    goto BBA
    
AFTER_SUB
    ;check if count is bigger than ca, if so toggle io
    btfsc DIF_FLAG, 1
    call TOGGLE_IO
    
    ;otherwise update count values
    goto UPDATE
    
;-------------------------------------------------------------------------------
    
END
