/*
    SuperCollider iOS sclang C API
    Copyright (c) 2026 Daniel Raffel.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.
*/

#ifndef SC_IOS_SCLANG_H
#define SC_IOS_SCLANG_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Configuration for sclang initialization
typedef struct {
    int memorySpaceKB;          // Memory pool size in KB (default: 2048)
    int memoryGrowKB;           // Memory growth increment in KB (default: 256)
    const char* runtimeDir;     // Runtime directory (NULL = use default)
    const char* classLibraryDir; // Path to SCClassLibrary (NULL = use default)
} SCiOSSclangConfig;

// Post callback — receives interpreter output text
typedef void (*SCiOSSclangPostCallback)(const char* text, int length, void* context);

// Set the resource directory (e.g., app bundle path containing SCClassLibrary)
// Must be called before SCiOSSclangInit
void SCiOSSclangSetResourceDir(const char* path);

// Return default configuration
SCiOSSclangConfig SCiOSSclangConfigDefault(void);

// Initialize sclang runtime (call once)
bool SCiOSSclangInit(const SCiOSSclangConfig* config, char* errorBuf, int errorBufSize);

// Set post output callback
void SCiOSSclangSetPostCallback(SCiOSSclangPostCallback callback, void* context);

// Compile the class library
// Returns true if compilation succeeds
bool SCiOSSclangCompileLibrary(void);

// Recompile the class library (⌘K equivalent)
// Returns true if recompilation succeeds
bool SCiOSSclangRecompileLibrary(void);

// Check if class library is compiled
bool SCiOSSclangIsLibraryCompiled(void);

// Execute SuperCollider code string
// Returns true if execution was initiated (does not wait for completion)
bool SCiOSSclangInterpret(const char* code);

// Add a directory to the class library include paths (for user extensions)
// Must be called before SCiOSSclangCompileLibrary
void SCiOSSclangAddIncludePath(const char* path);

// Shut down sclang runtime
void SCiOSSclangShutdown(void);

#ifdef __cplusplus
}
#endif

#endif // SC_IOS_SCLANG_H
