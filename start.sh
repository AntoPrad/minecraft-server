#!/bin/bash
java -Xms6G -Xmx6G -XX:+UnlockExperimentalVMOptions -XX:+UseG1GC -XX:G1NewSizePercent=20 -XX:G1ReservePercent=20 -XX:MaxGCPauseMillis=50 -XX:G1HeapRegionSize=32M -jar fabric-server-mc.1.21.1-loader.0.18.0-launcher.1.1.0.jar nogui
