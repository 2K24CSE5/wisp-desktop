import configparser
import json
import os
import pwd


users = []
for account in pwd.getpwall():
    if account.pw_uid < 1000 or account.pw_uid >= 60000:
        continue
    if account.pw_shell in ("/sbin/nologin", "/usr/sbin/nologin", "/bin/false"):
        continue
    if not os.path.isdir(account.pw_dir):
        continue

    display_name = account.pw_name
    account_file = os.path.join("/var/lib/AccountsService/users", account.pw_name)
    parser = configparser.ConfigParser(interpolation=None)
    try:
        parser.read(account_file, encoding="utf-8")
        display_name = parser.get("User", "RealName", fallback=display_name).strip() or display_name
    except (configparser.Error, OSError):
        pass

    users.append({"username": account.pw_name, "name": display_name})

users.sort(key=lambda user: (user["name"].casefold(), user["username"].casefold()))
print(json.dumps(users))
