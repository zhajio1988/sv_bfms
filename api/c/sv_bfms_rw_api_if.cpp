/****************************************************************************
 * sv_bfms_rw_api_if.c
 ****************************************************************************/
#include "sv_bfms_rw_api_if.h"
#include <stdio.h>
#include <stdexcept>

#include "dlutils.h"
#if defined(_WIN32) || defined (__CYGWIN__)
#define EXPORT __declspec(dllexport)
#else
#ifdef __cplusplus
#define EXPORT extern "C"
#else
#define EXPORT
#endif
#endif

typedef void *svScope;

static svScope (*svGetScopeF)(void) = 0;
static void (*svSetScopeF)(svScope) = 0;
static svScope prvScope = 0;

static int (*_sv_bfms_rw_api_write8)(void *, uint32_t, uint8_t);
static int (*_sv_bfms_rw_api_read8)(void *, uint32_t, uint8_t *);
static int (*_sv_bfms_rw_api_write32)(void *, uint32_t, uint32_t);
static int (*_sv_bfms_rw_api_read32)(void *, uint32_t, uint32_t *);
static void (*svAckDisabledStateF)(void) = 0;
static int (*svIsDisabledStateF)(void) = 0;

EXPORT int _sv_bfms_rw_api_init(void) {
	// Lookup functions
	void *hndl = get_process_hndl();

	svGetScopeF = (svScope (*)(void))get_symbol(hndl, "svGetScope");
	svSetScopeF = (void (*)(svScope))get_symbol(hndl, "svSetScope");
	svAckDisabledStateF = (void (*)(void))get_symbol(hndl, "svAckDisabledState");
	svIsDisabledStateF = (int (*)(void))get_symbol(hndl, "svIsDisabledState");
	_sv_bfms_rw_api_write8 = (int (*)(void *,uint32_t,uint8_t))
			get_symbol(hndl, "_sv_bfms_rw_api_write8");
	_sv_bfms_rw_api_read8 = (int (*)(void *,uint32_t,uint8_t*))
			get_symbol(hndl, "_sv_bfms_rw_api_read8");
	_sv_bfms_rw_api_write32 = (int (*)(void *,uint32_t,uint32_t))
			get_symbol(hndl, "_sv_bfms_rw_api_write32");
	_sv_bfms_rw_api_read32 = (int (*)(void *,uint32_t,uint32_t*))
			get_symbol(hndl, "_sv_bfms_rw_api_read32");

	prvScope = svGetScopeF();

	return 1;
}

EXPORT void sv_bfms_write32(void *hndl, uint32_t addr, uint32_t data) {
	svSetScopeF(prvScope);
	if (_sv_bfms_rw_api_write32(hndl, addr, data)) {
		svAckDisabledStateF();
		throw std::runtime_error("sv_bfms_write32");
	}
}

EXPORT uint32_t sv_bfms_read32(void *hndl, uint32_t addr) {
	uint32_t data;
	svSetScopeF(prvScope);
	if (_sv_bfms_rw_api_read32(hndl, addr, &data)) {
		svAckDisabledStateF();
		throw std::runtime_error("sv_bfms_read32");
	}

	return data;
}

EXPORT void sv_bfms_write8(void *hndl, uint32_t addr, uint8_t data) {
	if (svIsDisabledStateF()) {
		return ;
	}
	svSetScopeF(prvScope);
	if (_sv_bfms_rw_api_write8(hndl, addr, data)) {
		svAckDisabledStateF();
		throw std::runtime_error("sv_bfms_read32");
	}
}

EXPORT uint8_t sv_bfms_read8(void *hndl, uint32_t addr) {
	uint8_t data;
	if (svIsDisabledStateF()) {
		return 1;
	}
	svSetScopeF(prvScope);
	if (_sv_bfms_rw_api_read8(hndl, addr, &data)) {
		svAckDisabledStateF();
		throw std::runtime_error("sv_bfms_read32");
	}

	return data;
}
