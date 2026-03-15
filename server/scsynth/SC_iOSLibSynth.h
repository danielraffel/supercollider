/*
    SuperCollider iOS Public C API
    Copyright (c) 2026 Daniel Raffel.
    http://www.audiosynth.com

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
*/

#ifndef SC_IOS_LIB_SYNTH_H
#define SC_IOS_LIB_SYNTH_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque server handle
typedef struct SCiOSServer* SCiOSServerRef;

// Server configuration with sensible defaults
typedef struct {
    double sampleRate;          // Preferred sample rate (default: 48000.0)
    int blockSize;              // Audio block size (default: 64)
    int numInputChannels;       // 0 to disable input (default: 2)
    int numOutputChannels;      // Stereo output (default: 2)
    int maxNodes;               // Max synth nodes (default: 1024)
    int maxGraphDefs;           // Max SynthDef slots (default: 1024)
    int realtimeMemorySize;     // RT memory in KB (default: 8192)
    int numWireBufs;            // Wire buffers (default: 64)
    int numAudioBusChannels;    // Audio buses (default: 1024)
    int numControlBusChannels;  // Control buses (default: 16384)
    int numSampleBuffers;       // Sample buffers (default: 1024)
    bool verbose;               // Log to console (default: true)
    const char* synthDefSearchPath; // Path to .scsyndef files (NULL for none)
} SCiOSServerConfig;

// OSC message callback
typedef void (*SCiOSReplyCallback)(void* context, const uint8_t* data, int dataSize);

// Return a config struct with sensible defaults
SCiOSServerConfig SCiOSServerConfigDefault(void);

// Lifecycle
SCiOSServerRef SCiOSServerCreate(const SCiOSServerConfig* config, char* errorBuf, int errorBufSize);
bool SCiOSServerStart(SCiOSServerRef server);
void SCiOSServerStop(SCiOSServerRef server);
void SCiOSServerDestroy(SCiOSServerRef server);

// Send OSC packet (in-process, no network needed)
bool SCiOSServerSendOSC(SCiOSServerRef server, const uint8_t* packet, int packetSize);

// Set callback for OSC replies from the server
void SCiOSServerSetReplyCallback(SCiOSServerRef server, SCiOSReplyCallback callback, void* context);

// Status queries
bool SCiOSServerIsRunning(SCiOSServerRef server);
double SCiOSServerActualSampleRate(SCiOSServerRef server);
int SCiOSServerActualBlockSize(SCiOSServerRef server);
int SCiOSServerNumUGens(SCiOSServerRef server);
int SCiOSServerNumSynths(SCiOSServerRef server);
float SCiOSServerAvgCPU(SCiOSServerRef server);
float SCiOSServerPeakCPU(SCiOSServerRef server);

// Version string
const char* SCiOSServerVersion(void);

// Get the internal World pointer (for connecting sclang to this server)
void* SCiOSServerGetWorld(SCiOSServerRef server);

#ifdef __cplusplus
}
#endif

#endif // SC_IOS_LIB_SYNTH_H
