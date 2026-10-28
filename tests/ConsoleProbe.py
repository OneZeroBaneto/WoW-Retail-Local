"""Compile the actual pinned CLI source with lightweight game-world stubs.
On Windows, real GetConsoleMode inspects the subprocess pipes; on macOS only
that Win32 boundary is stubbed. This does not build or test the whole core.
"""
import argparse
import pathlib
import shutil
import subprocess
import tempfile

repo = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--unpatched', action='store_true')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='wow-console-probe-') as directory:
    work = pathlib.Path(directory)
    source = work / 'src/server/worldserver/CommandLine/CliRunnable.cpp'
    source.parent.mkdir(parents=True)
    shutil.copyfile(repo / 'tests/native/upstream/CliRunnable.cpp', source)
    if not args.unpatched:
        subprocess.run(['git', 'apply', str(repo / 'patches/0001-windows-pipe-console.patch')], cwd=work, check=True)
    exe = work / ('probe.exe' if __import__('os').name == 'nt' else 'probe')
    stubs = repo / 'tests/native/stubs'
    if __import__('os').name == 'nt':
        command = ['cl', '/nologo', '/EHsc', '/std:c++17', '/DTRINITY_PLATFORM=1', '/DTRINITY_PLATFORM_WINDOWS=1', f'/I{stubs}', str(source), str(repo / 'tests/native/main.cpp'), f'/Fe:{exe}', 'user32.lib']
    else:
        command = ['clang++', '-std=c++17', '-DTRINITY_PLATFORM=1', '-DTRINITY_PLATFORM_WINDOWS=1', '-I', str(stubs), '-I', str(repo / 'tests/native/windows'), str(source), str(repo / 'tests/native/main.cpp'), '-o', str(exe)]
    subprocess.run(command, cwd=work, check=True)
    result = subprocess.run([str(exe)], input='help\r\nserver shutdown 0\r\n', text=True, capture_output=True, timeout=5)
    assert result.returncode == 0, f'CLI commands not delivered: exit {result.returncode}; {result.stdout!r}'
    assert 'ACK:help' in result.stdout and 'ACK:server shutdown 0' in result.stdout, result.stdout
    print('PASS: pinned C++ CLI reads two piped commands, prints their results and terminates.')
