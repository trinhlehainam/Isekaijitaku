#!/bin/bash

# Check CPU and architecture
CPU_INFO=$(sysctl -n machdep.cpu.brand_string)
ARCH=$(arch)

echo "CPU Information: $CPU_INFO"
echo "Current Architecture: $ARCH"

if echo "$CPU_INFO" | grep -q "Apple M"; then
    echo "Recommendation: Download arm64 version for best performance"
    echo "Even if running under Rosetta (x86_64), arm64 is recommended for M-series Macs"
else
    echo "Recommendation: Download amd64 version (Intel Mac)"
fi

# Print current architecture details
if [ "$ARCH" = "arm64" ]; then
    echo "Running natively on ARM"
elif [ "$ARCH" = "x86_64" ]; then
    if echo "$CPU_INFO" | grep -q "Apple M"; then
        echo "Running under Rosetta 2 on M-series Mac"
    else
        echo "Running natively on Intel"
    fi
fi
