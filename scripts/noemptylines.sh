#!/bin/sh

egrep "-" db.whiteboard > db.whiteboard.tmp
rm db.whiteboard
mv db.whiteboard.tmp db.whiteboard
