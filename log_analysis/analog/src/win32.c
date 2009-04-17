/***             analog 5.32             http://www.analog.cx/             ***/
/*** This program is copyright (c) Stephen R. E. Turner 1995 - 2003 except as
 *** stated otherwise. Distribution, usage and modification of this program is
 *** subject to the conditions of the Licence which you should have received
 *** with it. This program comes with no warranty, expressed or implied.   ***/

/*** win32.c; stuff only required for the Win32 port ***/
/* This stuff is due to Magnus Hagander (mha@edu.sollentuna.se) */
#include "anlghea3.h"
#ifdef WIN32

/*
 * Initialize the required Win32 structures and routines
 */

void Win32Init(void) {
#ifndef NODNS
  WSADATA wsaData;

  if (WSAStartup(MAKEWORD(1,1),&wsaData))
    error("unable to initialise winsock.dll");
#endif
#ifndef NOPRIORITY
  SetThreadPriority(GetCurrentThread(),THREAD_PRIORITY_BELOW_NORMAL);
#endif
}

/*
 * Cleanup Win32 structures and routines
 */
void Win32Cleanup(void) {
#ifndef NODNS
  WSACleanup();
#endif
}
#endif
