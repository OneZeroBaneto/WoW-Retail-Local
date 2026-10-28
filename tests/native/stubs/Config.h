#pragma once
struct Config { bool GetBoolDefault(char const*, bool) { return false; } };
inline Config config;
inline Config* sConfigMgr = &config;
