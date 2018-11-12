#!/usr/bin/env bash
rm -f game.love
zip -x *.git* -x deploy.sh -r game.love .
butler push game.love madeso/spelsylt2018:love

