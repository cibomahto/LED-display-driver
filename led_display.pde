// Sketch to drive a hacked 80x7 2-color LED display
// By Matt Mets

// Hardware SPI hints from
//http://www.arduino.cc/en/Tutorial/SPIDigitalPot
//// http://softsolder.wordpress.com/2009/07/18/arduino-hardware-assisted-spi-synchronous-serial-data-io/


// 7 pins that turn on the rows
unsigned char rowPins[] = {2, 3, 4, 5, 6, 7, 8};

// Colored Stripes
unsigned char testPatternB[] = {0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6,
                                0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d,
                                0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d, 0xdb, 0xb6, 0x6d};


#define DATAOUT 11      //MOSI
#define DATAIN 12       //MISO - not used, but part of builtin SPI
#define SPICLOCK  13    //sck


char spi_transfer(volatile char data)
{
  
  SPDR = data;                    // Start the transmission
  while (!(SPSR & (1<<SPIF))) {   // Wait the end of the transmission
  }
  return SPDR;                    // return the received byte
}


       
// Initialize the IO ports
void setup()
{
  Serial.begin(9600);
  
  byte clr;
  pinMode(DATAOUT, OUTPUT);
  pinMode(DATAIN, INPUT);
  pinMode(SPICLOCK,OUTPUT);
  
  pinMode(10, OUTPUT);
  digitalWrite(10, LOW);
  
  // SPCR = 01010000
  //interrupt disabled,spi enabled,msb 1st,master,clk low when idle,
  //sample on leading edge of clk,system clock/4 (fastest)
  SPCR = (1<<SPE)|(1<<MSTR);
  clr=SPSR;
  clr=SPDR;
  delay(10);

  
  // Setup row select lines
  for (int i = 0; i < sizeof(rowPins); i++) {
    pinMode(rowPins[i], OUTPUT);
    digitalWrite(rowPins[i], LOW);
  }
}



// Draw a full row onto the screen
// Data should be in raw screen format: interleved bytes of green and red data.
void drawRow(unsigned char* screenData, unsigned char row)
{  
  // Just dump each byte to the screen
  for (int i= 0; i < 20; i++) {
    spi_transfer(screenData[i]);
  }
  
  digitalWrite(rowPins[row], HIGH);
  delayMicroseconds(500);
  digitalWrite(rowPins[row], LOW);
}

 
// Main loop
void loop()
{
  drawRow(testPatternB,     0);
  drawRow(testPatternB + 1, 1);  
  drawRow(testPatternB + 2, 2);
  drawRow(testPatternB,     3);
  drawRow(testPatternB + 1, 4);  
  drawRow(testPatternB + 2, 5);
  drawRow(testPatternB,     6);
  
//  delay(20);
}
