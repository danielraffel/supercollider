/*
    SuperCollider real time audio synthesis system
    Copyright (c) 2002 James McCartney. All rights reserved.
    Copyright (c) 2026 Daniel Raffel. iOS port.
    http://www.audiosynth.com

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
*/

#pragma once

#ifdef SC_IOS

#include <functional>

class SCiOSAudioSessionManager {
public:
    struct Config {
        double preferredSampleRate = 48000.0;
        double preferredBufferDuration = 0.005; // ~256 frames at 48kHz
        bool enableInput = true;
        bool mixWithOthers = false;
    };

    struct RuntimeConfig {
        double actualSampleRate;
        double actualBufferDuration;
        int actualBufferSize; // frames per callback
        int inputChannels;
        int outputChannels;
    };

    enum class State {
        Inactive,
        Active,
        Interrupted
    };

    using InterruptionCallback = std::function<void(bool began)>;
    using RouteChangeCallback = std::function<void()>;

    SCiOSAudioSessionManager();
    ~SCiOSAudioSessionManager();

    bool configure(const Config& config);
    bool activate();
    void deactivate();

    State getState() const;
    RuntimeConfig getRuntimeConfig() const;

    void setInterruptionCallback(InterruptionCallback cb);
    void setRouteChangeCallback(RouteChangeCallback cb);

    // Called from ObjC notification handlers
    void handleInterruption(bool began);
    void handleRouteChange();

private:
    class Impl;
    Impl* mImpl;
};

#endif // SC_IOS
