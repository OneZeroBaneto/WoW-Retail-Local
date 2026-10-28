#include "World.h"
#include "CliRunnable.h"
int main() { CliThread(); return World::count == 2 ? 0 : 7; }
