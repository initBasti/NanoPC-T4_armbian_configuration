#!/bin/bash

#INPUT: [remote-user] [remote-ip-address] [number of frames]

if [ "$#" -ne 4 ]; then
    echo "Usage: {script} [remote-user] [remote-ip] [camera] [number of frames to be captured]"
    exit
fi

remote_user=$1
ip=$2
remote="ssh $remote_user@$ip"

remote_in=/home/$remote_user/lib_stream_$3.raw
local_in=/home/$USER/lib_stream_$3.raw
local_out=/home/$USER/lib_out_camera_$3.mp4

# Start the recording and move the finished data from the NanoPC-T4 to the host
$remote LIBCAMERA_LOG_LEVELS=0 cam --camera=$3 --capture=$4 --file=$remote_in
rsync --progress $remote_user@$ip:$remote_in $local_in
$remote rm $remote_in

if ! [[ -f $local_in ]]; then
    echo "Capture or rsync failed."
fi

# Convert using the standard settings
ffmpeg -f rawvideo -vcodec rawvideo -s 1920x1920 -r 30 -pix_fmt nv21 -i $local_in -c:v libx264 -preset ultrafast -qp 0 -y -hide_banner $local_out
rm $local_in

# Watch the movie
mpv $local_out
