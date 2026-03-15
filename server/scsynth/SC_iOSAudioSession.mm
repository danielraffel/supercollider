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

#ifdef SC_IOS

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#include "SC_iOSAudioSession.h"
#include <atomic>
#include <mutex>

extern "C" int scprintf(const char* fmt, ...);

// ObjC observer for AVAudioSession notifications
@interface SCiOSAudioSessionObserver : NSObject
@property (nonatomic, assign) SCiOSAudioSessionManager* manager;
- (instancetype)initWithManager:(SCiOSAudioSessionManager*)manager;
@end

@implementation SCiOSAudioSessionObserver

- (instancetype)initWithManager:(SCiOSAudioSessionManager*)mgr {
    self = [super init];
    if (self) {
        _manager = mgr;

        NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(handleInterruption:)
                   name:AVAudioSessionInterruptionNotification
                 object:[AVAudioSession sharedInstance]];
        [nc addObserver:self
               selector:@selector(handleRouteChange:)
                   name:AVAudioSessionRouteChangeNotification
                 object:[AVAudioSession sharedInstance]];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)handleInterruption:(NSNotification*)notification {
    NSDictionary* info = notification.userInfo;
    AVAudioSessionInterruptionType type =
        (AVAudioSessionInterruptionType)[info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];

    if (type == AVAudioSessionInterruptionTypeBegan) {
        scprintf("SC iOS: audio session interruption began\n");
        _manager->handleInterruption(true);
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        scprintf("SC iOS: audio session interruption ended\n");
        _manager->handleInterruption(false);
    }
}

- (void)handleRouteChange:(NSNotification*)notification {
    NSDictionary* info = notification.userInfo;
    AVAudioSessionRouteChangeReason reason =
        (AVAudioSessionRouteChangeReason)[info[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];

    const char* reasonStr = "unknown";
    switch (reason) {
    case AVAudioSessionRouteChangeReasonNewDeviceAvailable:
        reasonStr = "new device available";
        break;
    case AVAudioSessionRouteChangeReasonOldDeviceUnavailable:
        reasonStr = "old device unavailable";
        break;
    case AVAudioSessionRouteChangeReasonCategoryChange:
        reasonStr = "category change";
        break;
    case AVAudioSessionRouteChangeReasonOverride:
        reasonStr = "override";
        break;
    default:
        break;
    }
    scprintf("SC iOS: audio route changed: %s\n", reasonStr);
    _manager->handleRouteChange();
}

@end

// Private implementation
class SCiOSAudioSessionManager::Impl {
public:
    SCiOSAudioSessionObserver* observer = nil;
    std::atomic<State> state { State::Inactive };
    std::mutex mutex;
    InterruptionCallback interruptionCallback;
    RouteChangeCallback routeChangeCallback;
    Config config;
    RuntimeConfig runtimeConfig {};
};

SCiOSAudioSessionManager::SCiOSAudioSessionManager() {
    mImpl = new Impl();
}

SCiOSAudioSessionManager::~SCiOSAudioSessionManager() {
    deactivate();
    mImpl->observer = nil;
    delete mImpl;
}

bool SCiOSAudioSessionManager::configure(const Config& config) {
    std::lock_guard<std::mutex> lock(mImpl->mutex);
    mImpl->config = config;

    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    // Set category
    AVAudioSessionCategory category;
    AVAudioSessionCategoryOptions options = 0;

    if (config.enableInput) {
        category = AVAudioSessionCategoryPlayAndRecord;
        options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        options |= AVAudioSessionCategoryOptionAllowBluetoothA2DP;
    } else {
        category = AVAudioSessionCategoryPlayback;
    }

    if (config.mixWithOthers) {
        options |= AVAudioSessionCategoryOptionMixWithOthers;
    }

    if (![session setCategory:category withOptions:options error:&error]) {
        scprintf("SC iOS: failed to set audio session category: %s\n",
                 error.localizedDescription.UTF8String);
        return false;
    }

    // Set preferred sample rate
    if (![session setPreferredSampleRate:config.preferredSampleRate error:&error]) {
        scprintf("SC iOS: failed to set preferred sample rate: %s\n",
                 error.localizedDescription.UTF8String);
        return false;
    }

    // Set preferred buffer duration
    if (![session setPreferredIOBufferDuration:config.preferredBufferDuration error:&error]) {
        scprintf("SC iOS: failed to set preferred buffer duration: %s\n",
                 error.localizedDescription.UTF8String);
        return false;
    }

    // Set up notification observer
    if (!mImpl->observer) {
        mImpl->observer = [[SCiOSAudioSessionObserver alloc] initWithManager:this];
    }

    scprintf("SC iOS: audio session configured (SR=%.0f, bufDur=%.4f, input=%s)\n",
             config.preferredSampleRate, config.preferredBufferDuration,
             config.enableInput ? "yes" : "no");
    return true;
}

bool SCiOSAudioSessionManager::activate() {
    std::lock_guard<std::mutex> lock(mImpl->mutex);

    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    if (![session setActive:YES error:&error]) {
        scprintf("SC iOS: failed to activate audio session: %s\n",
                 error.localizedDescription.UTF8String);
        return false;
    }

    // Read actual runtime values after activation
    mImpl->runtimeConfig.actualSampleRate = session.sampleRate;
    mImpl->runtimeConfig.actualBufferDuration = session.IOBufferDuration;
    mImpl->runtimeConfig.actualBufferSize = (int)(session.sampleRate * session.IOBufferDuration + 0.5);
    mImpl->runtimeConfig.inputChannels = (int)session.inputNumberOfChannels;
    mImpl->runtimeConfig.outputChannels = (int)session.outputNumberOfChannels;

    mImpl->state.store(State::Active);

    scprintf("SC iOS: audio session activated (actual SR=%.0f, bufSize=%d, in=%d, out=%d)\n",
             mImpl->runtimeConfig.actualSampleRate,
             mImpl->runtimeConfig.actualBufferSize,
             mImpl->runtimeConfig.inputChannels,
             mImpl->runtimeConfig.outputChannels);
    return true;
}

void SCiOSAudioSessionManager::deactivate() {
    std::lock_guard<std::mutex> lock(mImpl->mutex);

    if (mImpl->state.load() == State::Inactive) return;

    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSError* error = nil;

    if (![session setActive:NO error:&error]) {
        scprintf("SC iOS: warning: failed to deactivate audio session: %s\n",
                 error.localizedDescription.UTF8String);
    }

    mImpl->state.store(State::Inactive);
    scprintf("SC iOS: audio session deactivated\n");
}

SCiOSAudioSessionManager::State SCiOSAudioSessionManager::getState() const {
    return mImpl->state.load();
}

SCiOSAudioSessionManager::RuntimeConfig SCiOSAudioSessionManager::getRuntimeConfig() const {
    return mImpl->runtimeConfig;
}

void SCiOSAudioSessionManager::setInterruptionCallback(InterruptionCallback cb) {
    std::lock_guard<std::mutex> lock(mImpl->mutex);
    mImpl->interruptionCallback = std::move(cb);
}

void SCiOSAudioSessionManager::setRouteChangeCallback(RouteChangeCallback cb) {
    std::lock_guard<std::mutex> lock(mImpl->mutex);
    mImpl->routeChangeCallback = std::move(cb);
}

void SCiOSAudioSessionManager::handleInterruption(bool began) {
    if (began) {
        mImpl->state.store(State::Interrupted);
    } else {
        // Re-activate on interruption end
        AVAudioSession* session = [AVAudioSession sharedInstance];
        NSError* error = nil;
        if ([session setActive:YES error:&error]) {
            mImpl->state.store(State::Active);
        } else {
            scprintf("SC iOS: failed to reactivate after interruption: %s\n",
                     error.localizedDescription.UTF8String);
        }
    }

    std::lock_guard<std::mutex> lock(mImpl->mutex);
    if (mImpl->interruptionCallback) {
        mImpl->interruptionCallback(began);
    }
}

void SCiOSAudioSessionManager::handleRouteChange() {
    // Update runtime config after route change
    AVAudioSession* session = [AVAudioSession sharedInstance];
    mImpl->runtimeConfig.actualSampleRate = session.sampleRate;
    mImpl->runtimeConfig.actualBufferDuration = session.IOBufferDuration;
    mImpl->runtimeConfig.actualBufferSize = (int)(session.sampleRate * session.IOBufferDuration + 0.5);
    mImpl->runtimeConfig.inputChannels = (int)session.inputNumberOfChannels;
    mImpl->runtimeConfig.outputChannels = (int)session.outputNumberOfChannels;

    std::lock_guard<std::mutex> lock(mImpl->mutex);
    if (mImpl->routeChangeCallback) {
        mImpl->routeChangeCallback();
    }
}

#endif // SC_IOS
