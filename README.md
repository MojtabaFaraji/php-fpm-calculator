# PHP-FPM Configuration Calculator

> Automatically calculate optimal PHP-FPM pool settings based on your server's resources

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

---

## About

Stop guessing your PHP-FPM settings. This script analyzes your server's RAM and running PHP-FPM processes to generate optimal configuration values.

| Setting | Description |
|---------|-------------|
| `pm.max_children` | Maximum number of child processes |
| `pm.start_servers` | Processes to start on boot |
| `pm.min_spare_servers` | Minimum idle processes |
| `pm.max_spare_servers` | Maximum idle processes |

---

## Quick Install

```bash
curl -sSL https://gist.githubusercontent.com/MojtabaFaraji/66e073a9a02137ce9874170e44689901/raw/34d1a2f69f1f5e6d5fdf13f909f73db22b8ef6df/php-fpm-calculator.sh | bash
```

Or download manually:

```bash
wget https://gist.githubusercontent.com/MojtabaFaraji/66e073a9a02137ce9874170e44689901/raw/34d1a2f69f1f5e6d5fdf13f909f73db22b8ef6df/php-fpm-calculator.sh
chmod +x php-fpm-calculator.sh
./php-fpm-calculator.sh
```

---

## Usage

```bash
./php-fpm-calculator.sh           # Standard output
./php-fpm-calculator.sh --verbose # Detailed debug info
./php-fpm-calculator.sh -v        # Same as --verbose
```

---

## Example Output

```
=== PHP-FPM Configuration Calculator ===

=== System Information ===
Total RAM:              4096MB
CPU Cores:              4
Reserved System RAM:    1024MB (25%)
Available for PHP:      3072MB
Avg FPM Process Memory: ~75MB

=== Recommended PHP-FPM Settings ===
Add these to your www.conf file:

pm = dynamic
pm.max_children = 40
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 20

pm.max_requests = 500
pm.process_idle_timeout = 10s
```

---

## How It Works

**System Detection** - Reads total RAM (`free -m` with `/proc/meminfo` fallback) and CPU cores (`nproc` with `/proc/cpuinfo` fallback)

**Process Measurement** - Detects running PHP-FPM processes (`php-fpm`, `php-fpm8`, `php-fpm7`) and calculates average RSS memory from `/proc/[pid]/statm`

**Calculation** - Reserves 25% RAM for OS, divides remaining by average process memory, applies safety limits (min: 2, max: 1000 children)

---

## Requirements

- Linux (uses `/proc` filesystem)
- Bash 4.0+
- PHP-FPM (optional, but recommended for accurate measurements)

---

## Use Cases

- Setting up new servers
- Optimizing existing PHP-FPM configuration
- Debugging out-of-memory errors
- Server capacity planning
- Load testing preparation

---

## Contributing

1. Fork the Gist
2. Make your improvements
3. Share with the community

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**⭐ Support**
- If this script helped you, give it a star on GitHub!
- Found it useful? Share it with your team or on social media.
