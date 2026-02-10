#!/bin/bash
VERSION=$1
DATE=$(date +"%Y-%m-%d")

# Add release to Done section
sed -i "/## Done /a \\\n### Version $VERSION ($DATE)\\\n- See [CHANGELOG.md](CHANGELOG.md) for details\\\n" ROADMAP.md
