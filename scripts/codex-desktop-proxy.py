"""Adapt Desktop's JSONL proxy to Codex's WebSocket Unix listener."""

import argparse
import asyncio
import os
from pathlib import Path
import sys

from websockets.asyncio.client import unix_connect


async def proxy(socket_path: str) -> None:
    loop = asyncio.get_running_loop()
    reader = asyncio.StreamReader(limit=256 * 1024 * 1024)
    input_transport, _ = await loop.connect_read_pipe(
        lambda: asyncio.StreamReaderProtocol(reader), sys.stdin.buffer
    )
    output_transport, protocol = await loop.connect_write_pipe(
        asyncio.streams.FlowControlMixin, sys.stdout.buffer
    )
    writer = asyncio.StreamWriter(output_transport, protocol, None, loop)
    try:
        async with unix_connect(
            path=socket_path,
            uri="ws://localhost/rpc",
            max_size=None,
            ping_interval=None,
            open_timeout=10,
        ) as websocket:

            async def send() -> None:
                while line := await reader.readline():
                    if line.strip():
                        await websocket.send(line.decode("utf-8").rstrip("\r\n"))

            async def receive() -> None:
                async for message in websocket:
                    if isinstance(message, bytes):
                        message = message.decode("utf-8")
                    writer.write(message.encode("utf-8") + b"\n")
                    await writer.drain()

            tasks = [asyncio.create_task(send()), asyncio.create_task(receive())]
            try:
                done, _ = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
                for task in done:
                    task.result()
            finally:
                for task in tasks:
                    task.cancel()
                await asyncio.gather(*tasks, return_exceptions=True)
    finally:
        input_transport.close()
        output_transport.close()


def proxy_command_index(args: list[str]) -> int | None:
    """Recognize the command after the global options supported by this adapter."""
    index = 0
    value_options = {"-c", "--config", "--enable", "--disable"}
    while index < len(args):
        argument = args[index]
        if argument in value_options:
            if index + 1 == len(args):
                return None
            index += 2
        elif argument.partition("=")[0] in value_options and "=" in argument:
            index += 1
        elif argument.startswith("-c") and len(argument) > 2:
            index += 1
        else:
            break
    if args[index : index + 2] == ["app-server", "proxy"]:
        return index
    return None


def main() -> None:
    upstream, *args = sys.argv[1:]
    index = proxy_command_index(args)
    if index is not None:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--sock")
        parser.add_argument("-c", "--config", action="append")
        parser.add_argument("--enable", action="append")
        parser.add_argument("--disable", action="append")
        options = parser.parse_args(args[:index] + args[index + 2 :])
        codex_home = Path(os.environ.get("CODEX_HOME", Path.home() / ".codex"))
        socket_path = options.sock or str(
            codex_home / "app-server-control" / "app-server-control.sock"
        )
        try:
            asyncio.run(proxy(socket_path))
        except (OSError, ValueError, EOFError) as error:
            print(f"codex desktop proxy: {error}", file=sys.stderr)
            sys.exit(1)
        return
    os.execv(upstream, [upstream, *args])


if __name__ == "__main__":
    main()
