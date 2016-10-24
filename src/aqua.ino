
#include <Wire.h>
#include <SPI.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_BME280.h>

#define SEALEVELPRESSURE_HPA (1020.0)

Adafruit_BME280 bme; // I2C

void setup() {
  Serial.begin(9600);
  Serial.println(F("BME280 test"));

  if (!bme.begin()) {
    Serial.println("Could not find a valid BME280 sensor, check wiring!");
    while (1);
  }
}


void loop() {
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
    Serial.println("%");

    delay(1000);
}

