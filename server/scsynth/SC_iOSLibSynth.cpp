/*
    SuperCollider iOS Public C API — Implementation
    Copyright (c) 2026 Daniel Raffel.
    http://www.audiosynth.com

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
*/

#ifdef SC_IOS

#include "SC_iOSLibSynth.h"
#include "SC_WorldOptions.h"
#include "SC_World.h"
#include "SC_HiddenWorld.h"
#include "SC_CoreAudio.h"

#include <cstring>
#include <cstdio>
#include <mutex>

struct SCiOSServer {
    World* world;
    SCiOSReplyCallback replyCallback;
    void* replyContext;
    std::mutex mutex;
    bool running;
};

static void sciosReplyFunc(struct ReplyAddress* addr, char* msg, int size) {
    // The reply address context pointer holds our server ref
    if (addr && addr->mReplyData) {
        SCiOSServer* server = (SCiOSServer*)addr->mReplyData;
        if (server->replyCallback) {
            server->replyCallback(server->replyContext, (const uint8_t*)msg, size);
        }
    }
}

SCiOSServerConfig SCiOSServerConfigDefault(void) {
    SCiOSServerConfig config;
    config.sampleRate = 48000.0;
    config.blockSize = 64;
    config.numInputChannels = 2;
    config.numOutputChannels = 2;
    config.maxNodes = 1024;
    config.maxGraphDefs = 1024;
    config.realtimeMemorySize = 8192;
    config.numWireBufs = 64;
    config.numAudioBusChannels = 1024;
    config.numControlBusChannels = 16384;
    config.numSampleBuffers = 1024;
    config.verbose = true;
    config.synthDefSearchPath = nullptr;
    return config;
}

SCiOSServerRef SCiOSServerCreate(const SCiOSServerConfig* config, char* errorBuf, int errorBufSize) {
    if (!config) {
        if (errorBuf && errorBufSize > 0)
            snprintf(errorBuf, errorBufSize, "config is NULL");
        return nullptr;
    }

    WorldOptions options;
    options.mPreferredSampleRate = (uint32)config->sampleRate;
    options.mBufLength = config->blockSize;
    options.mNumInputBusChannels = config->numInputChannels;
    options.mNumOutputBusChannels = config->numOutputChannels;
    options.mMaxNodes = config->maxNodes;
    options.mMaxGraphDefs = config->maxGraphDefs;
    options.mRealTimeMemorySize = config->realtimeMemorySize;
    options.mMaxWireBufs = config->numWireBufs;
    options.mNumAudioBusChannels = config->numAudioBusChannels;
    options.mNumControlBusChannels = config->numControlBusChannels;
    options.mNumBuffers = config->numSampleBuffers;
    options.mVerbosity = config->verbose ? 1 : -1;
    options.mRealTime = true;
    options.mRendezvous = false; // No Bonjour on iOS

    // Plugin path not needed for static plugins
    options.mUGensPluginPath = nullptr;

    // SynthDef search path
    if (config->synthDefSearchPath) {
        options.mLoadGraphDefs = 1;
    }

    World* world = World_New(&options);
    if (!world) {
        if (errorBuf && errorBufSize > 0)
            snprintf(errorBuf, errorBufSize, "World_New failed");
        return nullptr;
    }

    SCiOSServer* server = new SCiOSServer();
    server->world = world;
    server->replyCallback = nullptr;
    server->replyContext = nullptr;
    server->running = false;

    return server;
}

bool SCiOSServerStart(SCiOSServerRef server) {
    if (!server || !server->world) return false;

    std::lock_guard<std::mutex> lock(server->mutex);
    if (server->running) return true; // Already running

    // The audio driver is started by World_New via Setup() and Start()
    // World_New creates the audio driver, calls Setup() and Start()
    server->running = true;
    return true;
}

void SCiOSServerStop(SCiOSServerRef server) {
    if (!server) return;

    std::lock_guard<std::mutex> lock(server->mutex);
    if (!server->running) return;

    // Stop the audio driver
    if (server->world && server->world->hw && server->world->hw->mAudioDriver) {
        server->world->hw->mAudioDriver->Stop();
    }
    server->running = false;
}

void SCiOSServerDestroy(SCiOSServerRef server) {
    if (!server) return;

    SCiOSServerStop(server);

    if (server->world) {
        World_Cleanup(server->world, false);
        server->world = nullptr;
    }

    delete server;
}

bool SCiOSServerSendOSC(SCiOSServerRef server, const uint8_t* packet, int packetSize) {
    if (!server || !server->world || !packet || packetSize <= 0) return false;

    // Create a copy of the packet (World_SendPacket takes ownership)
    char* packetCopy = (char*)malloc(packetSize);
    if (!packetCopy) return false;
    memcpy(packetCopy, packet, packetSize);

    return World_SendPacketWithContext(server->world, packetSize, packetCopy,
                                       sciosReplyFunc, server);
}

void SCiOSServerSetReplyCallback(SCiOSServerRef server, SCiOSReplyCallback callback, void* context) {
    if (!server) return;
    server->replyCallback = callback;
    server->replyContext = context;
}

bool SCiOSServerIsRunning(SCiOSServerRef server) {
    if (!server) return false;
    return server->running;
}

double SCiOSServerActualSampleRate(SCiOSServerRef server) {
    if (!server || !server->world || !server->world->hw || !server->world->hw->mAudioDriver)
        return 0.0;
    return server->world->hw->mAudioDriver->GetSampleRate();
}

int SCiOSServerActualBlockSize(SCiOSServerRef server) {
    if (!server || !server->world) return 0;
    return server->world->mBufLength;
}

int SCiOSServerNumUGens(SCiOSServerRef server) {
    if (!server || !server->world) return 0;
    return server->world->mNumUnits;
}

int SCiOSServerNumSynths(SCiOSServerRef server) {
    if (!server || !server->world) return 0;
    return server->world->mNumGraphs;
}

float SCiOSServerAvgCPU(SCiOSServerRef server) {
    if (!server || !server->world || !server->world->hw || !server->world->hw->mAudioDriver)
        return 0.0f;
    return (float)server->world->hw->mAudioDriver->GetAvgCPU();
}

float SCiOSServerPeakCPU(SCiOSServerRef server) {
    if (!server || !server->world || !server->world->hw || !server->world->hw->mAudioDriver)
        return 0.0f;
    return (float)server->world->hw->mAudioDriver->GetPeakCPU();
}

const char* SCiOSServerVersion(void) {
    return "SuperCollider scsynth iOS 3.15.0-dev";
}

#endif // SC_IOS
