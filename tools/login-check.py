"""Log in to a blakserv and print the login-mode conversation; check AP_SHARDS_INFO.

    python tools/login-check.py --user NAME --password PASS [--host 127.0.0.1] [--port 5960]
    python tools/login-check.py                 # first account in run/shards/test-accounts.txt

Speaks the original login protocol (doc/login.txt, clientd3d/login.c): the server sends
AP_GETLOGIN, we send AP_LOGIN as upstream's client 7.37 does (no 104 secret key), then
print every message up to the character menu (AP_GETCHOICE) and log off.
Exit codes: 0 logged in and got AP_SHARDS_INFO, 1 logged in without it (an upstream
server), 2 login failed or protocol error. Standard library only.
"""
import argparse
import hashlib
import pathlib
import socket
import struct
import sys

AP_NAMES = {21: 'AP_GETLOGIN', 22: 'AP_GETCHOICE', 23: 'AP_LOGINOK', 24: 'AP_LOGINFAILED',
            25: 'AP_GAME', 27: 'AP_ACCOUNTUSED', 28: 'AP_TOOMANYLOGINS', 29: 'AP_TIMEOUT',
            31: 'AP_DOWNLOAD', 34: 'AP_MESSAGE', 37: 'AP_NOCHARACTERS', 60: 'AP_SHARDS_INFO',
            7: 'AP_GETCLIENT'}
AP_LOGIN, AP_GETLOGIN, AP_GETCHOICE, AP_LOGINOK, AP_SHARDS_INFO = 2, 21, 22, 23, 60
CLIENT_MAJOR, CLIENT_MINOR = 7, 37  # upstream clientd3d/client.h


def frame(body: bytes) -> bytes:
    # u16 length | u16 crc (unchecked in login mode) | u16 length | u8 epoch (blakserv/session.c)
    return struct.pack('<HHHB', len(body), 0, len(body), 0) + body


def lstring(b: bytes) -> bytes:
    return struct.pack('<H', len(b)) + b


def password_digest(password: str) -> bytes:
    # util/md5.c MDString: MD5 of the password, 0x00 bytes replaced by 0x01
    return bytes(b or 1 for b in hashlib.md5(password.encode('latin-1')).digest())


def recv_frames(sock: socket.socket):
    buf = b''
    while True:
        while len(buf) >= 7:
            length, _crc, length2, _epoch = struct.unpack_from('<HHHB', buf)
            if length != length2:
                raise ValueError(f'bad header {buf[:7].hex()}')
            if len(buf) < 7 + length:
                break
            yield buf[7:7 + length]
            buf = buf[7 + length:]
        chunk = sock.recv(65536)
        if not chunk:
            return
        buf += chunk


def default_account() -> tuple[str, str]:
    path = pathlib.Path(__file__).resolve().parent.parent / 'run' / 'shards' / 'test-accounts.txt'
    for line in path.read_text().splitlines():
        if line.strip() and not line.startswith('#'):
            user, password = line.split()[:2]
            return user, password
    raise SystemExit(f'no account in {path}')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--host', default='127.0.0.1')
    ap.add_argument('--port', type=int, default=5960)
    ap.add_argument('--user')
    ap.add_argument('--password')
    args = ap.parse_args()
    user, password = (args.user, args.password) if args.user else default_account()

    login = (bytes([AP_LOGIN, CLIENT_MAJOR, CLIENT_MINOR])
             + struct.pack('<iiiii', 2, 10, 0, 1 << 30, 586)    # os type/major/minor, RAM, cpu
             + struct.pack('<HH', 1920, 1080)                   # screen
             + struct.pack('<iii', 0, 0, 32)                    # displays, bandwidth, reserved
             + lstring(user.encode('latin-1')) + lstring(password_digest(password)))

    shards = None
    with socket.create_connection((args.host, args.port), timeout=10) as sock:
        for body in recv_frames(sock):
            kind = body[0]
            name = AP_NAMES.get(kind, f'unknown {kind}')
            if kind == AP_SHARDS_INFO:
                version, n = struct.unpack_from('<iH', body, 1)
                server_name = body[7:7 + n].decode('latin-1')
                shards = version
                print(f'< {name}: protocol version {version}, server "{server_name}"')
            else:
                print(f'< {name} ({len(body) - 1} bytes)')
            if kind == AP_GETLOGIN:
                sock.sendall(frame(login))
                print(f'> AP_LOGIN as {user} (client {CLIENT_MAJOR}.{CLIENT_MINOR})')
            elif kind in (24, 27, 28, 29, 34, 7):
                print('login did not succeed')
                return 2
            elif kind == AP_GETCHOICE:
                break
    if shards is None:
        print('logged in; no AP_SHARDS_INFO (an upstream server, or Shards protocol 0)')
        return 1
    print(f'logged in; Shards protocol {shards}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
