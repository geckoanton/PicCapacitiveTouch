/*
 * Copyright (c) 2021 geckoanton
 * This code is licensed under MIT license (see LICENSE file for details)
 */

#include <xc.h>
#include "capacitiveTouch.h"

// this variable tells if the button is or is not already pressed
int lastState = 0;

void main(){
    //setting RC5 as output
    TRISCbits.TRISC5 = 0;
    
    //you need to call this function up on start of the program
    setupCapacitiveTouch();
    
    __delay_ms(1000);
    
    //calibrate after your exact setup
    calibrate();
    
    while(1){
        //checking if the button is getting pressed
        if(isTouching(15) && lastState == 0){
            if(RC5)
                RC5 = 0;
            else
                RC5 = 1;
            lastState = 1;
        }
        //checking if button is getting released
        else if(lastState == 1 && !isTouching(15))
            lastState = 0;
        
        __delay_ms(20);
    }
}
