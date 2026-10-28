# Windows server preparation

User-approved direction: develop on this Mac; all deployed services and game clients run on Windows. Separate repositories for Forever and Retail; Forever is the first gameplay target. Existing TBC files and databases are outside this implementation.

Deliver a local Git repository per variant, pinned upstream source/database provenance, PowerShell 7.4+ scripts, Windows batch entrypoints, Windows CI definition, setup/backup/gameplay documentation and a source-only ZIP. No game client, map data, passwords or machine-specific state is committed. No GitHub publication is required for local preparation.

Use native Windows x64, Visual Studio 2022, CMake, MySQL 8.0, Boost and OpenSSL. Each server has its own MySQL data directory and database prefix. Bind all services to loopback. Default authentication/game ports overlap, therefore only one variant runs at once; reject occupied ports rather than kill other processes. Stop worldserver through its console shutdown command before MySQL shutdown. Refuse backup while a supervisor is active. The runtime directory is machine-bound and must be configured again after moving the project.

A source pin and successful PowerShell tests are preparation evidence, not Windows binary or gameplay acceptance. The first Windows run must validate compilation, extracted data, login, restart persistence and the documented core gameplay checklist. The client launcher must match the selected client build; do not invent compatibility.
