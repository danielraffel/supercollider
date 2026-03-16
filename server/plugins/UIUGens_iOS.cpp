/*
    UIUGens stub for iOS — MouseX, MouseY, MouseButton, KeyState
    Returns constant values since there's no mouse/keyboard on iOS.
*/

#include "SC_PlugIn.h"

static InterfaceTable* ft;

struct MouseInputUGen : public Unit {
    float m_val;
};

struct KeyStateUGen : public Unit {
    float m_val;
};

static void MouseX_Ctor(MouseInputUGen* unit) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    unit->m_val = (minval + maxval) * 0.5f;
    ZOUT0(0) = unit->m_val;
}

static void MouseX_next(MouseInputUGen* unit, int inNumSamples) {
    float val = unit->m_val;
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = val;
}

static void MouseY_Ctor(MouseInputUGen* unit) {
    MouseX_Ctor(unit);
}

static void MouseButton_Ctor(MouseInputUGen* unit) {
    unit->m_val = ZIN0(0); // minval (not pressed)
    ZOUT0(0) = unit->m_val;
}

static void KeyState_Ctor(KeyStateUGen* unit) {
    unit->m_val = 0.f;
    ZOUT0(0) = 0.f;
}

static void KeyState_next(KeyStateUGen* unit, int inNumSamples) {
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = 0.f;
}

void UIUGens_Load(InterfaceTable* inTable) {
    ft = inTable;

    (*ft->fDefineUnit)("MouseX", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseX_Ctor, 0, 0);
    (*ft->fDefineUnit)("MouseY", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseY_Ctor, 0, 0);
    (*ft->fDefineUnit)("MouseButton", sizeof(MouseInputUGen),
                       (UnitCtorFunc)MouseButton_Ctor, 0, 0);
    (*ft->fDefineUnit)("KeyState", sizeof(KeyStateUGen),
                       (UnitCtorFunc)KeyState_Ctor, 0, 0);
}
