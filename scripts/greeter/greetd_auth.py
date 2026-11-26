#!/usr/bin/env python3
import json
import os
import socket
import struct
import sys

MAX_MESSAGE_SIZE = 1024 * 1024
SOCKET_TIMEOUT_SECONDS = 4


class GreeterAuthError(Exception):
    pass


def send_message(connection, message):
    payload = json.dumps(message).encode("utf-8")
    connection.sendall(struct.pack("=I", len(payload)) + payload)


def receive_exactly(connection, length):
    result = bytearray()
    while len(result) < length:
        chunk = connection.recv(length - len(result))
        if not chunk:
            if not result:
                return None
            raise GreeterAuthError("greetd closed the connection unexpectedly")
        result.extend(chunk)
    return bytes(result)


def receive_message(connection):
    header = receive_exactly(connection, 4)
    if header is None:
        return None

    length = struct.unpack("=I", header)[0]
    if length > MAX_MESSAGE_SIZE:
        raise GreeterAuthError("greetd sent an oversized response")

    payload = receive_exactly(connection, length)
    if payload is None:
        raise GreeterAuthError("greetd sent an incomplete response")
    try:
        message = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise GreeterAuthError("greetd sent an invalid response") from error
    if not isinstance(message, dict):
        raise GreeterAuthError("greetd sent an invalid response")
    return message


def response_description(response, fallback):
    description = response.get("description")
    return description.strip() if isinstance(description, str) and description.strip() else fallback


def authentication_failure_detail(authentication_errors, response):
    detail = authentication_errors[-1] if authentication_errors else response_description(
        response, "Incorrect password. Please try again."
    )
    normalized_detail = detail.lower()
    if "auth_err" in normalized_detail or "pam_authenticate" in normalized_detail:
        return "Incorrect password. Please try again."
    return detail


def cancel_session(connection):
    try:
        send_message(connection, {"type": "cancel_session"})
    except OSError:
        pass


def authenticate(connection, username, password):
    send_message(connection, {"type": "create_session", "username": username})
    response = receive_message(connection)
    authentication_errors = []

    while response and response.get("type") == "auth_message":
        message_type = response.get("auth_message_type")
        message = response.get("auth_message")

        if message_type == "error":
            if isinstance(message, str) and message.strip():
                authentication_errors.append(message.strip())
            reply = {"type": "post_auth_message_response"}
        elif message_type == "info":
            reply = {"type": "post_auth_message_response"}
        elif message_type == "secret":
            reply = {"type": "post_auth_message_response", "response": password}
        elif message_type == "visible":
            reply = {"type": "post_auth_message_response", "response": username}
        else:
            reply = {"type": "post_auth_message_response"}

        send_message(connection, reply)
        response = receive_message(connection)

    if response and response.get("type") == "success":
        return

    cancel_session(connection)
    if response and response.get("type") == "error":
        if response.get("error_type") == "auth_error":
            detail = authentication_failure_detail(authentication_errors, response)
            raise GreeterAuthError("Authentication failed: " + detail)
        raise GreeterAuthError(response_description(response, "Could not create an authenticated session"))
    if response is None:
        raise GreeterAuthError("greetd closed the connection during authentication")
    raise GreeterAuthError(response_description(response, "Unexpected response from greetd"))


def start_session(connection, username, session_command):
    environment = {
        "XDG_SESSION_TYPE": "wayland",
        "USER": username,
        "LOGNAME": username,
        "PATH": "/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin",
        "XDG_DATA_DIRS": "/usr/local/share:/usr/share",
    }
    for key in ("XDG_RUNTIME_DIR", "LANG", "LC_ALL", "LC_CTYPE"):
        value = os.environ.get(key)
        if value and len(value) < 250:
            environment[key] = value

    command = ["systemd-cat", "--identifier=wisp-session", "--", *session_command]
    send_message(connection, {
        "type": "start_session",
        "cmd": command,
        "env": [f"{key}={value}" for key, value in environment.items()],
    })
    response = receive_message(connection)
    if response and response.get("type") == "success":
        return

    cancel_session(connection)
    if response and response.get("type") == "error":
        raise GreeterAuthError(response_description(response, "Could not start the selected session"))
    if response is None:
        raise GreeterAuthError("greetd closed the connection while starting the session")
    raise GreeterAuthError(response_description(response, "Unexpected response from greetd"))


def main(arguments):
    if len(arguments) != 4:
        raise GreeterAuthError("Invalid greetd helper arguments")

    username, session_command_json, socket_path = arguments[1:]
    password_line = sys.stdin.readline()
    if not password_line:
        raise GreeterAuthError("Password was not provided")
    try:
        password = json.loads(password_line)
        session_command = json.loads(session_command_json)
    except json.JSONDecodeError as error:
        raise GreeterAuthError("Invalid authentication input") from error
    if not isinstance(password, str) or not password:
        raise GreeterAuthError("Password was not provided")
    if not isinstance(session_command, list) or not session_command or not all(
        isinstance(part, str) for part in session_command
    ):
        raise GreeterAuthError("Invalid session command")

    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(SOCKET_TIMEOUT_SECONDS)
        connection.connect(socket_path)
        authenticate(connection, username, password)
        start_session(connection, username, session_command)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except socket.timeout:
        print("Authentication request timed out", file=sys.stderr)
        sys.exit(1)
    except (OSError, GreeterAuthError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
