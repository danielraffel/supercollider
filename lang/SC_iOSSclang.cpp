/*
    SuperCollider iOS sclang C API — Implementation
    Copyright (c) 2026 Daniel Raffel.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
*/

#if defined(SC_IOS)

#include "SC_iOSSclang.h"
#include "SC_LanguageClient.h"
#include "SC_LanguageConfig.hpp"
#include "SC_Filesystem.hpp"
#include <mutex>
#include <cstring>
#include <cstdio>

// Defined in SC_Filesystem_iphone.cpp
extern void SC_Filesystem_SetResourceDir(const char* path);

// Post callback state
static SCiOSSclangPostCallback gPostCallback = nullptr;
static void* gPostContext = nullptr;
static std::mutex gSclangMutex;

// Concrete SC_LanguageClient for iOS
class SC_iOSLanguageClient : public SC_LanguageClient {
public:
    SC_iOSLanguageClient() : SC_LanguageClient("sclang-ios") {}

    void postText(const char* str, size_t len) override {
        if (gPostCallback) {
            gPostCallback(str, static_cast<int>(len), gPostContext);
        }
    }

    void postFlush(const char* str, size_t len) override {
        if (gPostCallback) {
            gPostCallback(str, static_cast<int>(len), gPostContext);
        }
    }

    void postError(const char* str, size_t len) override {
        if (gPostCallback) {
            gPostCallback(str, static_cast<int>(len), gPostContext);
        }
    }

    void flush() override {
        // No buffering needed for iOS callback model
    }
};

static SC_iOSLanguageClient* gClient = nullptr;

void SCiOSSclangSetResourceDir(const char* path) {
    SC_Filesystem_SetResourceDir(path);
}

SCiOSSclangConfig SCiOSSclangConfigDefault(void) {
    SCiOSSclangConfig config;
    config.memorySpaceKB = 2048;
    config.memoryGrowKB = 256;
    config.runtimeDir = nullptr;
    config.classLibraryDir = nullptr;
    return config;
}

bool SCiOSSclangInit(const SCiOSSclangConfig* config, char* errorBuf, int errorBufSize) {
    std::lock_guard<std::mutex> lock(gSclangMutex);

    if (gClient) {
        if (errorBuf && errorBufSize > 0)
            snprintf(errorBuf, errorBufSize, "sclang already initialized");
        return false;
    }

    gClient = new SC_iOSLanguageClient();

    SC_LanguageClient::Options opts;
    if (config) {
        opts.mMemSpace = config->memorySpaceKB * 1024;
        opts.mMemGrow = config->memoryGrowKB * 1024;
        if (config->runtimeDir) {
            opts.mRuntimeDir = config->runtimeDir;
        }
    }

    // If a custom class library dir is provided, set it as the resource directory
    // so sclang finds SCClassLibrary inside the app bundle
    if (config && config->classLibraryDir) {
        SC_Filesystem_SetResourceDir(config->classLibraryDir);
    }

    gClient->initRuntime(opts);
    return true;
}

void SCiOSSclangSetPostCallback(SCiOSSclangPostCallback callback, void* context) {
    gPostCallback = callback;
    gPostContext = context;
}

bool SCiOSSclangCompileLibrary(void) {
    std::lock_guard<std::mutex> lock(gSclangMutex);

    if (!gClient) {
        return false;
    }

    // standalone=false means use default class library paths
    gClient->compileLibrary(false);
    return gClient->isLibraryCompiled();
}

bool SCiOSSclangIsLibraryCompiled(void) {
    if (!gClient) return false;
    return gClient->isLibraryCompiled();
}

bool SCiOSSclangInterpret(const char* code) {
    std::lock_guard<std::mutex> lock(gSclangMutex);

    if (!gClient || !gClient->isLibraryCompiled()) {
        return false;
    }

    gClient->setCmdLine(code);
    gClient->interpretCmdLine();
    return true;
}

void SCiOSSclangShutdown(void) {
    std::lock_guard<std::mutex> lock(gSclangMutex);

    if (gClient) {
        if (gClient->isLibraryCompiled()) {
            gClient->shutdownLibrary();
        }
        gClient->shutdownRuntime();
        destroyLanguageClient(gClient);
        gClient = nullptr;
    }
}

#endif // SC_IOS
