#include <avr/wdt.h>
#include <ClickEncoder.h>
#include <TimerOne.h>
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>

#include "Adafruit_VCNL4010.h"
Adafruit_VCNL4010 vcnl;

#include "RunningAverage.h"

int encoderpinA = 3;
int encoderpinB = 4;
int buttonpin  = 12;

ClickEncoder *encoder;
int16_t last, value;

void timerIsr() {
	encoder->service();
}

#define SEALEVELPRESSURE_HPA (1020.0)

Adafruit_BME280 bme; // I2C

RunningAverage avgPr(15);
RunningAverage avgLx(15);

void setup() {
	// immediately disable watchdog timer so set will not get interrupted
	wdt_disable();

  Serial.begin(9600);

  // Serial.println(F("Encoder"));
  encoder = new ClickEncoder(encoderpinA, encoderpinB, buttonpin);
  
  Timer1.initialize(1000);
  Timer1.attachInterrupt(timerIsr); 
  
  last = -1;

  //Serial.println(F("BME280"));

  if (!bme.begin()) {
    Serial.println("Could not find a valid BME280 sensor, check wiring!");
    while (1);
  }
  Serial.println(F("VCNL4010 test"));

  if (! vcnl.begin()){
    Serial.println(F("Sensor not found :("));
    while (1);
  }
  Serial.println(F("Found VCNL4010"));

	avgPr.clear(); // explicitly start clean
	avgLx.clear(); // explicitly start clean

	// Watchdog timer enabled 4 second count down
	wdt_enable(WDTO_4S);


}


void loop() {
	value += encoder->getValue();

	Serial.print("T=");
	Serial.print(bme.readTemperature());
	Serial.print("*C ");

	Serial.print("P=");

	Serial.print(bme.readPressure() / 100.0F);
	Serial.print("hPa ");

	Serial.print("A=");
	Serial.print(bme.readAltitude(SEALEVELPRESSURE_HPA));
	Serial.print("m ");

	Serial.print("H=");
	Serial.print(bme.readHumidity());
	Serial.print("%");

	Serial.print(" EV=");

	if (value != last) {
		last = value;
		Serial.print(value);

	}else{
		Serial.print(last);
	}

	avgLx.addValue(vcnl.readAmbient());
	Serial.print(" Lx=");
	Serial.print(avgLx.getAverage());

//	avgPr.addValue(vcnl.readProximity());
	Serial.print(" Pr=");
	Serial.print(vcnl.readProximity());

  Serial.print(" B=");

  ClickEncoder::Button b = encoder->getButton();
  if (b != ClickEncoder::Open) {
    #define VERBOSECASE(label) case label: Serial.println(#label); break;
    switch (b) {
      VERBOSECASE(ClickEncoder::Pressed);
      VERBOSECASE(ClickEncoder::Held)
      VERBOSECASE(ClickEncoder::Released)
      VERBOSECASE(ClickEncoder::Clicked)
      case ClickEncoder::DoubleClicked:
          Serial.println("ClickEncoder::DoubleClicked");
        break;
    }
  }


	Serial.println();


	delay(1000);
  wdt_reset();
}

