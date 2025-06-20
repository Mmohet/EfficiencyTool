# EfficiencyTool

A bash script wrapped with Swift to send PIDs to the efficiency core.

## Overview

EfficiencyTool is a utility for macOS designed to help you manage how your apps use your Mac's efficiency and performance cores. By wrapping a Bash script with a Swift interface, EfficiencyTool lets you assign specific process IDs (PIDs) to the efficiency core for better system resource management. It is especially useful for Chromium-based browsers and Electron apps.

## Features

- Assign specific PIDs to the efficiency core for more efficient resource usage.
- Customizable rules to define how and when processes are targeted.
- Intelligent repeat times: the tool automatically manages cooldown periods to avoid running too frequently.
- Balance mode: uses CPU usage detection to optimize assignments and avoid causing system lags.
- Designed for safe use, but offers advanced options for users who want more control.

## Requirements

- macOS with support for efficiency/performance cores (Apple Silicon recommended)
- Swift and Bash (both are installed by default on macOS)
- For building from source: Xcode with support for macOS 14 or later and an active macOS development environment

## Installation

1. Download the latest `.zip` file from the [Releases](https://github.com/Mmohet/EfficiencyTool/releases) page.
2. Uncompress the downloaded file.
3. Move the EfficiencyTool app to your Applications folder, or simply double-click to run.

### Building from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/Mmohet/EfficiencyTool.git
   cd EfficiencyTool
   ```
2. Install Xcode (version supporting macOS 14+).
3. Make sure your macOS development environment is set up.
4. Open the project in Xcode and build as usual.

## Usage

1. Use Activity Monitor to find the process keyword or PID you want to manage.
2. Launch EfficiencyTool.
3. Set up your custom rules, or use the default rules provided by the tool.
4. Be careful when enabling "Front Stage Detection" or "All PIDs Detection"—these advanced options can affect system performance if not used properly.
5. EfficiencyTool works best with Chromium browsers and Electron apps.

## Notes

- Do not use the tool indiscriminately with all processes; it is intended for targeted use.
- Take care with advanced detection options, as they may impact foreground apps and overall user experience.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you'd like to help improve EfficiencyTool.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Acknowledgements

- Inspired by the need for better resource management on Apple Silicon.
- Utilizes Swift for scripting efficiency and safety.
