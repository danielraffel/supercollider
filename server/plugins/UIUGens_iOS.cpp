/*
    UIUGens stub for iOS — MouseX, MouseY, MouseButton, KeyState
    These UGens have no mouse/keyboard input on iOS, so they output
    constant default values (midpoint for Mouse, 0 for KeyState).
*/

#if defined(SC_IOS) || defined(SC_IPHONE)

#include "SC_PlugIn.h"

static InterfaceTable* ft;

struct MouseInputUGen : public Unit {
    float m_y1, m_b1, m_lag;
};

struct KeyState : public Unit {
    float m_y1, m_b1, m_lag;
};

// MouseX: outputs a value between minval and maxval (default: midpoint)
void MouseX_Ctor(MouseInputUGen* unit) {
    SETCALC(MouseX_Ctor); // Use constructor as calc func (constant output)
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    // Default to midpoint
    ZOUT0(0) = (minval + maxval) * 0.5f;
    unit->m_y1 = ZOUT0(0);
}

void MouseX_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    float val = (minval + maxval) * 0.5f;
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = val;
}

// MouseY: same as MouseX
void MouseY_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float maxval = ZIN0(1);
    float val = (minval + maxval) * 0.5f;
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = val;
}

// MouseButton: always 0 (not pressed)
void MouseButton_next(MouseInputUGen* unit, int inNumSamples) {
    float minval = ZIN0(0);
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = minval;
}

// KeyState: always 0 (not pressed)
void KeyState_next(KeyState* unit, int inNumSamples) {
    float* out = ZOUT(0);
    for (int i = 0; i < inNumSamples; ++i)
        out[i] = 0.f;
}

#define DefineDtorCantAliasUnit(name) (*ft->fDefineDtorCantAliasUnit)(sizeof(name), #name, \
    (UnitCtorFunc)&name##_Ctor, (UnitDtorFunc)0, 0)

void UIUGens_Ctor(MouseInputUGen* unit) {
    SETCALC(MouseX_next);
    ZOUT0(0) = 0.f;
    unit->m_y1 = 0.f;
}

extern "C" {
    void UIUGens_Load(InterfaceTable* inTable) {
        ft = inTable;

        // Use DefineSimpleUnit for basic UGens
        DefineSimpleUnit(MouseInputUGen);  // This won't match the class name

        // Register each UGen by name
        (*ft->fDefineUnit)("MouseX", sizeof(MouseInputUGen), (UnitCtorFunc)&MouseX_Ctor, 0, 0);
        (*ft->fDefineUnit)("MouseY", sizeof(MouseInputUGen), (UnitCtorFunc)&MouseX_Ctor, 0, 0);
        (*ft->fDefineUnit)("MouseButton", sizeof(MouseInputUGen), (UnitCtorFunc)&MouseX_Ctor, 0, 0);
        (*ft->fDefineUnit)("KeyState", sizeof(KeyState), (UnitCtorFunc)&MouseX_Ctor, 0, 0);
    }
}

#endif // SC_IOS
