#pragma once
#include "World.h"
#include <optional>
#include <cstdio>
#include <Windows.h>
template <typename T> using Optional = std::optional<T>;
inline bool ReadWinConsole(std::string&) {
    // The original core calls ReadConsoleW on a pipe, which fails. Stop this
    // probe after the failure rather than reproducing its infinite busy loop.
    World::StopNow(1);
    return false;
}
inline void WriteWinConsole(std::string_view) { /* No pipe output, as in upstream. */ }
inline Optional<std::size_t> RemoveCRLF(std::string& text) {
    auto p = text.find_first_of("\r\n");
    if (p == std::string::npos) return std::nullopt;
    text.erase(p);
    return p;
}
