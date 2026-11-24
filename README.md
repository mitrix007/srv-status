# srv-status

Two small scripts that report host/service health.

| File | What it does |
|------|--------------|
| `srv-status.sh` | Colour-coded `good`/`bad` for a fixed list of systemd/process names (nginx, php-fpm, mariadb, vsftpd, firewalld, …). |
| `check_services.sh` | Fuller dashboard: service states, disk/memory load with WARN/CRIT thresholds, very low noise. Called from `~/.bashrc` (as `.check_services.sh`) for a login banner. |
| `check_ralf_ru.sh` | Curls the ralf.ru / loymax.ralf.ru endpoints and prints the HTTP status line for each. |

Both are plain bash, no dependencies beyond coreutils and `tput`.

```bash
cp srv-status.sh /usr/local/bin/ && chmod +x /usr/local/bin/srv-status.sh
cp check_services.sh /root/sh/.check_services.sh
echo '[[ -f /root/sh/.check_services.sh ]] && /root/sh/.check_services.sh' >> ~/.bashrc
```

`check_services.sh` degrades gracefully when `TERM` is unset (cron, non-interactive SSH).
