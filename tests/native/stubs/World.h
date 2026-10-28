#pragma once
#include <string>
#include <string_view>
inline constexpr int SHUTDOWN_EXIT_CODE = 0;
struct CliCommandHolder {
    using Print = void(*)(void*, std::string_view);
    using Done = void(*)(void*, bool);
    std::string command;
    Print print;
    Done done;
    CliCommandHolder(void*, char const* c, Print p, Done d): command(c), print(p), done(d) {}
};
struct World {
    inline static bool stopped = false;
    inline static int count = 0;
    static bool IsStopped() { return stopped; }
    static void StopNow(int) { stopped = true; }
    void QueueCliCommand(CliCommandHolder* c) {
        ++count;
        c->print(nullptr, "ACK:" + c->command + "\n");
        if (c->command == "server shutdown 0") stopped = true;
        c->done(nullptr, true);
        delete c;
    }
};
inline World world;
inline World* sWorld = &world;
