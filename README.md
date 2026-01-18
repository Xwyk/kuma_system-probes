# kuma_system-probes

System monitoring scripts to send metrics to an Uptime Kuma instance.

## Description

This project provides system probes (CPU, RAM, disk) that send their metrics to Uptime Kuma via the Push API. Everything is orchestrated by a main script that reads a JSON configuration and launches the different probes.

## Maximum Compatibility

**No external dependencies required** - Scripts only use standard tools present on any Linux distribution:
- `bash` - Base shell
- `grep`, `sed`, `awk` - Text manipulation
- `tr` - Character transformation
- `curl` - HTTP calls (usually pre-installed)
- `df`, `free` - Standard system tools

**Native JSON parsing** - No need for `jq` or other external JSON parser. The configuration file is parsed with `grep`, `sed` and `awk` for maximum compatibility, especially in minimalist Docker containers.

## Project Structure

```
.
├── launch.sh                 # Main orchestration script
├── config.example.json       # Configuration file example
└── scripts/
    ├── cpu.sh               # CPU probe
    ├── ram.sh               # RAM probe
    └── fs.sh                # Filesystem probe
```

## Configuration

The JSON configuration file defines:
- The base URL of the Uptime Kuma Push API
- Tokens and critical thresholds for each probe
- Mount points to monitor for filesystem probes

### Configuration File Format

```json
{
  "url": "https://uptime.example.com/api/push",
  "probes": {
    "cpu": {
      "token": "your_cpu_token",
      "threshold": 95
    },
    "ram": {
      "token": "your_ram_token",
      "threshold": 95
    },
    "fs": [
      {
        "token": "your_fs_root_token",
        "mount_point": "/",
        "threshold": 90
      },
      {
        "token": "your_fs_data_token",
        "mount_point": "/data",
        "threshold": 85
      }
    ]
  }
}
```

### Parameters

- **url**: Base URL of the Uptime Kuma Push API
- **token**: Unique token for each probe (generated in Uptime Kuma)
- **threshold**: Critical threshold in percentage (status changes to "down" if exceeded)
- **mount_point**: Mount point to monitor (only for filesystem probes)

## Usage

### Installation

1. Clone the repository
2. Make the main script executable:
```bash
chmod +x launch.sh
chmod +x scripts/*.sh
```

3. Create your configuration file:
```bash
cp config.example.json config.json
# Edit config.json with your tokens and parameters
```

### Execution

**Normal mode**:
```bash
./launch.sh -c config.json
```

**Dry-run mode** (displays URLs without sending them):
```bash
./launch.sh -d -c config.json
```

### Options

- `-c, --config FILE`: Path to configuration file (required)
- `-d, --dry-run`: Simulation mode (displays commands without executing them)
- `-h, --help`: Display help

## How It Works

### Architecture

1. **launch.sh** reads the JSON configuration file and parses values with standard tools
2. For each configured probe, it exports the necessary environment variables:
   - `KUMA_URL`: API URL
   - `KUMA_TOKEN`: Probe token
   - `CRITICAL_LIMIT`: Critical threshold
   - `MOUNT_POINT`: Mount point (for fs.sh)
3. It then launches each probe script which:
   - Collects its system metric
   - Compares it to its threshold
   - Sends the result to Uptime Kuma via curl

### Available Probes

#### CPU (cpu.sh)
- Measures CPU usage over 1 second
- Calculation based on `/proc/stat`
- Changes to "down" status if usage ≥ threshold

#### RAM (ram.sh)
- Measures RAM usage
- Calculation based on the `free` command
- Changes to "down" status if usage ≥ threshold

#### Filesystem (fs.sh)
- Measures usage of a mount point
- Based on the `df` command
- Changes to "down" status if usage ≥ threshold
- **Multi-mount support**: you can define multiple FS probes with different mount points

## Integration with Uptime Kuma

1. In Uptime Kuma, create a "Push" type monitor
2. Get the generated Push URL (format: `https://your-kuma/api/push/TOKEN`)
3. Extract the TOKEN from the URL
4. Configure your probes in config.json with:
   - `url`: The base part of the URL (without the token)
   - `token`: The token for each probe

## Automation

To run probes periodically, add a cron job:

```bash
# Run every 5 minutes
*/5 * * * * /path/to/kuma_system-probes/launch.sh -c /path/to/config.json
```

## Docker Deployment

Thanks to the absence of external dependencies, these scripts work in any basic Docker container:

```dockerfile
FROM alpine:latest
RUN apk add --no-cache bash curl
COPY . /app
RUN chmod +x /app/launch.sh /app/scripts/*.sh
CMD ["/app/launch.sh", "-c", "/app/config.json"]
```

## License

See LICENSE file
