#pragma once
// Portable probe only: simulate the documented redirected Win32 handles.
// Windows CI uses the real Windows SDK instead of this directory.
using DWORD = unsigned long;
using HANDLE = void*;
inline constexpr int STD_INPUT_HANDLE = -10, STD_OUTPUT_HANDLE = -11;
inline constexpr DWORD FLASHW_TRAY = 2, FLASHW_TIMERNOFG = 12;
struct FLASHWINFO { unsigned cbSize; HANDLE hwnd; DWORD dwFlags; unsigned uCount; DWORD dwTimeout; };
inline HANDLE GetStdHandle(int) { return nullptr; }
inline int GetConsoleMode(HANDLE, DWORD*) { return 0; }
inline HANDLE GetConsoleWindow() { return nullptr; }
inline int FlashWindowEx(FLASHWINFO*) { return 0; }
