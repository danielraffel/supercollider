// Bridging header for SuperCollider iOS C API
#import "SC_iOSLibSynth.h"
#import "SC_iOSSclang.h"

// UIUGens touch/motion input (defined in UIUGens_iOS.cpp)
void SC_iOS_SetMousePosition(float x, float y, bool button);
void SC_iOS_SetAccelerometer(float x, float y, float z);
