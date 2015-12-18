#!/bin/bash

TARGET="/usr/local/bin"

install -d ${TARGET}
install parasrv -t ${TARGET}
chown root:root ${TARGET}/parasrv
chmod +s ${TARGET}/parasrv