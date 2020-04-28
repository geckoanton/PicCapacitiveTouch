#define CALIBRATION_SAMPLE 20
#define TOUCH_SAMPLE 10
#define DISCHARGE_TIME 5

int count;
int calibrationValue, maxCalibrationValue, minCalibrationValue;

int getChargeTime(){
    int timerCount = 0;
    int overflowCount = 0;
    //discharge capacitance to be measured
    RC4 = 0;
    __delay_ms(DISCHARGE_TIME);  //give enough delay to fully (almost fully actually) discharge the "capacitor"
    //clear the timer overflow flag
    T0IF = 0;
    //wait for timer to overflow, start count from 0
    while(!T0IF);
    T0IF = 0;
    //start charging capacitance to be measured
    RC4 = 1;
    //wait for capacitance to charge up to the referance voltage
    while(C1OUT){
        timerCount = TMR0;
        if(T0IF){
            overflowCount++;
            T0IF = 0;
        }
    }
    count = (256 * overflowCount) + timerCount;
    //reset timerCount
    timerCount = 0;
    overflowCount = 0;
    
    return count;
}

int isTouching(int tolerance){
    //average of multiple samples
    double average = 0;
    for(int i = 0; i < TOUCH_SAMPLE; i++){
        if(getChargeTime() > calibrationValue + tolerance)
            average++;
    }
    average /= TOUCH_SAMPLE;
    
    //average will be a number between 0 and 1
    if(average > 0.2)
        return 1;
    
    return 0;
}

void calibrate(){
    int average = 0;
    int samples[CALIBRATION_SAMPLE];
    
    //get average value
    for(int i = 0; i < CALIBRATION_SAMPLE; i++){
        samples[i] = getChargeTime();
        average += samples[i];
    }
    average /= CALIBRATION_SAMPLE;
    calibrationValue = average;
    
    //get max/min values
    maxCalibrationValue = samples[0];
    minCalibrationValue = samples[0];
    for(int i = 0; i < CALIBRATION_SAMPLE; i++){
        if(samples[i] > maxCalibrationValue)
            maxCalibrationValue = samples[i];
        if(samples[i] < minCalibrationValue)
            minCalibrationValue = samples[i];
    }
}

void setupCapacitiveTouch(){
    //setting charge/discharge pin as output, in this case it's RC4
    TRISCbits.TRISC4 = 0;
    
    //setting up timer0
    T0CS = 0;
    PSA = 1;
    
    //setting up comparator
    C1CH0 = 0;
    C1CH1 = 0;
    
    C1R = 0;
    
    C1ON = 1;
    C1POL = 0;
    
    //clearing count values
    count = 0;
    
    //clearing calibration values
    calibrationValue = 0;
    maxCalibrationValue = 0;
    minCalibrationValue = 0;
    
    //run calibration on start
    calibrate();
}
