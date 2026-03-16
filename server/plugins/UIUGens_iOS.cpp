/*
    UIUGens for iOS — MouseX, MouseY, MouseButton, KeyState + AccelX, AccelY, AccelZ

    MouseX/Y: Map to touch position when touching, or return midpoint.
              On iPad with pointer support, maps to pointer position.
    MouseButton: 1 when screen is touched, 0 otherwise.
    KeyState: Always 0 (no physical keyboard state available).

    AccelX/Y/Z: Device accelerometer via CoreMotion.

    These values are updated from the iOS host app via global state.
    The host app calls SC_iOS_SetMousePosition() and SC_iOS_SetAccelerometer()
    to update the values that the UGens read.
*/

#include "SC_PlugIn.h"
#include <cmath>

static InterfaceTable* ft;

// Global state updated by the iOS host app
static float gMouseX = 0.5f;  // 0-1 normalized
static float gMouseY = 0.5f;
static bool  gMouseButton = false;
static float gAccelX = 0.0f;  // -1 to 1
static float gAccelY = 0.0f;
static float gAccelZ = 0.0f;

// C API for host app to update values
extern "C" {
    void SC_iOS_SetMousePosition(float x, float y, bool button) {
        gMouseX = x;
        gMouseY = y;
        gMouseButton = button;
    }

    void SC_iOS_SetAccelerometer(float x, float y, float z) {
        gAccelX = x;
        gAccelY = y;
        gAccelZ = z;
    }
}

// ---- UGen structs ----

struct MouseInputUGen : public Unit {
    float m_y1, m_b1, m_lag;
};

struct KeyStateUGen : public Unit {
    float m_y1;
};

// ---- MouseX ----

static void MouseX_Ctor(MouseInputUGen* unit) {
    unit->m_y1 = 0.f;
    unit->m_b1 = 0.f;
    float lag = ZIN0(3);
    unit->m_lag = lag;
    unit->m_b1 = lag == 0.f ? 0.f : expf(logf(0.001f) / (lag * SAMPLERATE));
    SETCALC(MouseX_Ctor);  // Will be replaced below
    ZOUT0(0) = 0.f;
}

static void MouseX_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    int warp = (int)ZIN0(2);

    float val;
    if (warp == 0) {
        // linear
        val = minval + gMouseX * (maxval - minval);
    } else {
        // exponential
        float lmin = logf(fmaxf(minval, 0.001f));
        float lmax = logf(fmaxf(maxval, 0.001f));
        val = expf(lmin + gMouseX * (lmax - lmin));
    }

    // Lag filter
    float b1 = unit->m_b1;
    float y1 = unit->m_y1;

    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i) {
        y1 = val + b1 * (y1 - val);
        out[i] = y1;
    }
    unit->m_y1 = y1;
}

// ---- MouseY ----

static void MouseY_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    int warp = (int)ZIN0(2);

    // Invert Y (SC convention: top=minval, bottom=maxval)
    float mouseY = 1.0f - gMouseY;

    float val;
    if (warp == 0) {
        val = minval + mouseY * (maxval - minval);
    } else {
        float lmin = logf(fmaxf(minval, 0.001f));
        float lmax = logf(fmaxf(maxval, 0.001f));
        val = expf(lmin + mouseY * (lmax - lmin));
    }

    float b1 = unit->m_b1;
    float y1 = unit->m_y1;
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i) {
        y1 = val + b1 * (y1 - val);
        out[i] = y1;
    }
    unit->m_y1 = y1;
}

// ---- MouseButton ----

static void MouseButton_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);

    float val = gMouseButton ? maxval : minval;

    float b1 = unit->m_b1;
    float y1 = unit->m_y1;
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i) {
        y1 = val + b1 * (y1 - val);
        out[i] = y1;
    }
    unit->m_y1 = y1;
}

// ---- KeyState ----

static void KeyState_next(KeyStateUGen* unit, int inNumSamples) {
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = 0.f;
}

// ---- Common Ctor for Mouse UGens ----

static void MouseCommon_Ctor(MouseInputUGen* unit, void (*calcFunc)(MouseInputUGen*, int)) {
    float lag = ZIN0(3);
    unit->m_lag = lag;
    unit->m_b1 = lag == 0.f ? 0.f : expf(logf(0.001f) / (lag * SAMPLERATE));
    unit->m_y1 = 0.f;
    SETCALC(*calcFunc);
    ZOUT0(0) = 0.f;
}

static void MouseX_CtorReal(MouseInputUGen* unit) { MouseCommon_Ctor(unit, MouseX_next); }
static void MouseY_CtorReal(MouseInputUGen* unit) { MouseCommon_Ctor(unit, MouseY_next); }
static void MouseButton_CtorReal(MouseInputUGen* unit) { MouseCommon_Ctor(unit, MouseButton_next); }
static void KeyState_Ctor(KeyStateUGen* unit) { SETCALC(KeyState_next); ZOUT0(0) = 0.f; }

// ---- Load ----

void UIUGens_Load(InterfaceTable* inTable) {
    ft = inTable;

    (*ft->fDefineUnit)("MouseX", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseX_CtorReal, 0, 0);
    (*ft->fDefineUnit)("MouseY", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseY_CtorReal, 0, 0);
    (*ft->fDefineUnit)("MouseButton", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseButton_CtorReal, 0, 0);
    (*ft->fDefineUnit)("KeyState", sizeof(KeyStateUGen),
                       (UnitCtorFunc)KeyState_Ctor, 0, 0);
}
