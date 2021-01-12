# My setup for kernel development (Media subsystem) on the NanoPC-T4

Last update: 2021-01-12

## Introduction

This is a summary of steps, that I have performed in order to have a running upstream kernel on my [NanoPC-T4](). I had to spend some time to figure out how to do it properly and would like to make this a little easier for anyone interested in working with this SBC (Single Board Computer), as well as myself in the future ;).

## Build system

There are a couple of build systems available: [Armbian](https://github.com/armbian/build), [Buildroot](https://github.com/buildroot/buildroot), [Yocto Project](https://www.yoctoproject.org/).
I have picked Armbian for its simplicity and speed and also because I didn't require too much customization.

Here are the steps required to build the image:

1. [Get the armbian build script](#get_the_script)
2. [Prepare the kernel configuration](#kernel_config)
3. [Adjust the specific set of patches that are required but not upstream](#adjust_patches)
4. [Configure the armbian script](#configure_armbian)
5. [Build the image and install it onto the SBC](#build_deploy)
6. [Test the image](#testing)  
    6.1 [Check if the fan works](#fan_check)  
    6.2 [Test if the camera works properly](#camera_test)  
    6.3 [Check if all subdevices of the camera pipeline exist](#camera_subdevices)  
    6.4 [Set up the camera pipeline](#camera_pipeline)  
    6.5 [Start a test recording](#test_capture)  
    6.6 [Record to a file and convert to a viewable format](#record_to_file_and_convert)  

7. [Additional topics](#additional_topics)  
    7.1 [Install additional packages with Ansible](#additional-packages)

---

### Get the armbian build script <a name=get_the_script></a>

```bash
git clone git@github.com:armbian/build.git
cd build
```

This project contains multiple sub-folders, the most important for us are: `userpatches` (here we do the configuration of the image building script), `output` (the destination for the image and possible debug messages), and `cache` (the compiled kernel sources are placed here). For more details look [here](https://github.com/armbian/build#build-tools-overview).

### Prepare the kernel configuration <a name=kernel_config></a>

This step depends heavily on your needs, I removed WLAN, Bluetooth, Virtualization, Touchscreen, USB-Webcams, DVB stuff, Video tuner, hardware video decoder and encoder drivers, Light sensors, and some other stuff, where I was sure that I wouldn't need it and where I felt confident enough to know that I don't cause damage.
You can start out with the configuration from armbian (under `config/kernel/linux-rockchip64-dev.config`) and then optimize it to your needs. My current version is located in this project under `userpatches/linux-rockchip64-dev.config`, this is the required name format for the config. [source](https://docs.armbian.com/Developer-Guide_User-Configurations/#user-provided-kernel-config)

### Adjust the specific set of patches that are required but not upstream <a name=adjust_patches></a>

If you take a look into `patch/kernel/rockchip64-dev`, you will find multiple patches, which are maintained by the armbian team to make sure that the hardware on your board works properly. There are device tree changes to declare certain hardware to your operating system and configure it, and a few tweaks and backports to drivers or core parts of the kernel. This is the biggest drawback, that I encountered due to using the latest kernel sources, you are responsible for making sure that these tweaks keep working. When there are changes within a patched file, you will have to look into the source code and find out if the tweak is still needed and if so you will have to manually apply the change and create a new patch out of it.

I approached this problem by first making sure, that the amount of patches I have to maintain is as small as possible. So at first, I filtered out all patches unrelated to rk3399 in general, then I moved on to patches that work on features I excluded in my configuration like WLAN, etc. **Every patch, that I do not require is copied into `userpatches/kernel/rockchip64-dev/`, and the content is deleted, this will cause the armbian script to skip it**. [source](https://docs.armbian.com/Developer-Guide_User-Configurations/#user-provided-patches)

I will do my best to keep this repository up-to-date, in which case that work is probably done by me (at least as long as you have the same requirements).
My current patch set is located in this repository under: `userpatches/kernel/rockchip64-dev/`. (Note, that these also include my personal patches, that may or may not be part of the upstream kernel)

*As a good habit: Only install changes that you understand at least to the extent that you can be sure that they will not harm your system.*

### Configure the armbian script <a name=configure_armbian></a>

There are mandatory and optional configurations:

#### Mandatory

We have to declare the source repository and the target branch, within the `lib.config` file in `userpatches/`.  
I use the following:
```bash
KERNELSOURCE="https://git.linuxtv.org/media_tree.git/"
KERNELBRANCH="branch:master"
```

Within the `config-*.conf`, we declare the following:

Choose the board to configure the image correctly, pick a branch to base your work on (`dev`).
```bash
BOARD="nanopct4"
BRANCH="dev"
```


#### Optional

I do not need a desktop for my purposes, all I need is a console, and so I disable the desktop environment. Additionally, I don't want a big badge of application that I never use, so I build the minimal version and pick the pre-installed application directly within the `lib.config` file.

`config-*.conf`:
```bash
BUILD_MINIMAL="yes"
BUILD_DESKTOP="no"
EXTERNAL_NEW="prebuilt"
```

Skip the interactive mode and go straight to the build, choose whether to build a whole new image (bootloader, pre-installed apps, etc) or just the kernel.
Additionally, pick the Debian/Ubuntu release you want to run on the NanoPC-T4.
```bash
KERNEL_ONLY="yes"
KERNEL_CONFIGURE="no"
RELEASE="bullseye"
```

Disable special sets of patches for features that I don't need.

```bash
EXTRAWIFI="no"
WIREGUARD="no"
AUFS="no"
```

Keyboard language setting:
```bash
DEST_LANG="en_US.UTF-8"			# sl_SI.UTF-8, en_US.UTF-8
```

**Update (2021-01-12):**  
**Currently the package list additional option does not work as intended for me (look [here](#additional-packages) for more information)**  
~~Pre-install applications on the image within the `lib.config` file:~~  

~~`lib.config`:~~  
~~PACKAGE_LIST_ADDITIONAL="$PACKAGE_LIST_ADDITIONAL python3 python3-dev python3-pip"~~  
~~Make sure that the packages you choose are available on the Debian release picked within the `RELEASE` option.~~  

#### Further customization of the image from the host machine

The `userpatches/customize-image.sh` script can be utilized to prepare your environment even more. For example, I use it to install applications from [PyPi](https://pypi.org/). You can do a lot more with this script. Ask in the [Armbian Forum](https://forum.armbian.com/), when you are unsure about a certain step.

```bash
Main() {
	case $RELEASE in
		stretch)
			# your code here
			# InstallOpenMediaVault # uncomment to get an OMV 4 image
			;;
		buster)
			# your code here
			;;
		bullseye)
                        # Install a recent version of meson for the root user
			python3 -m pip install meson --user --upgrade
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
	esac
} # Main
```

### Build the image and install it onto the SBC <a name=build_deploy></a>

Once, you have finished the steps above building the image is actually quite easy.

#### Building and burning to the SD-card

```bash
sudo ./compile.sh
```
If you added most of the configuration options mentioned above, you shouldn't see any interactive setup. The script now updates your system gets the latest sources for the bootloader and kernel, applies the patches to those sources, builds them and depending on your choice at the `KERNEL_ONLY` option builds the image.

In order to write the finished image from `output/image/Armbian_20.11.0-trunk_Nanopct4_{RELEASE}_{BRANCH}_{KERNELVERSION}_minimal.img` to the SD-card, I prefer to use [Balena Etcher](https://www.balena.io/etcher/), but there are multiple [alternatives](https://alternativeto.net/software/etcher/?platform=linux).

#### Boot on NanoPC-T4 <a name="boot_the_image">

The first thing you will have to do, is to set up the root password, the user login & password, and your full name. I usually quickly attach a USB-keyboard and a monitor for this step. But you can also log in directly via SSH, just be patient the first boot sometimes needs a bit of time. The login for the first boot with root is:
`ssh root@{IP-address}` and the password is: `1234`. In order to find out, which IP address was assigned to your NanoPC-T4, you could do the following:

```bash
ip -a
# Example output
# 2: enp1s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
#     inet 192.168.198.4/24 brd 192.168.198.255 scope global dynamic noprefixroute enp1s0
# Look at your IP address: Let's say it is '192.168.198.4',
# take the first three parts: '192.168.198' and add a '0' followed by the '/24'
sudo apt-get install nmap
sudo nmap -sn 192.168.198.0/24
# Locate an entry, which contains nanopct4 in its name and take the IP address.
```

### Test the image <a name=testing></a>

At this point, you have a running system, with a secure user and root password, as well as a running ssh connection. One of the first commands, I run to check if the patching went well is: `sudo dmesg`, here I check for any error/warning messages, any drivers that were not able to load, missing device tree nodes, etc. The next step is to check if the hardware behaves like expected, this includes the fan, a camera, the different USB ports, the HDMI port, the audio jack, and the NVME PCIe port for an external SSD, that is located on the backside of the board.

#### Check if the fan works <a name=fan_check>

This is in my opinion one of the most crucial checks because you probably don't want to damage your board unexpectedly.
A simple way to test if the fan works is by increasing the CPU temperature, here is a simple bash script, that repeatedly prints 'yes' to `/dev/null`, while using all processor cores of the system: [source](https://linuxconfig.org/how-to-stress-test-your-cpu-on-linux)
```bash
for i in $(seq $(getconf _NPROCESSORS_ONLN)); do yes > /dev/null & done
```

You can stop all those processes with: `killall yes`

The fan should start to spin quite rapidly within a short amount of time. If it doesn't, you should begin your investigation, the most obvious test is to check if the fan is connected properly. I noticed that the official fan by FriendlyElec twitches sometimes without actually starting to spin, if you nudge the fan a little, it may start spinning. After those simple tests, the first thing you might want to do is to configure the fan manually as described [here](http://wiki.friendlyarm.com/wiki/index.php/FriendlyThings_for_RK3399#PWM).

The easiest way to check the CPU temperature on RK3399 computers that I've discovered so far is with the `hardinfo` command. (`sudo apt-get install hardinfo`).
```bash
hardinfo -ma devices.so | grep Temperature
```

#### Testing the camera <a name=camera_test>

This part of the system is not crucial, but it is the area I am working on, so I take a closer look at it.

In order to perform those tests, I utilized the [`v4l-utils`](https://git.linuxtv.org//v4l-utils.git) applications and the [`libcamera`](http://libcamera.org/) project.
To install both on the armbian you will have to execute the following commands:

```bash
# Install dependencies
sudo apt-get install debhelper dh-autoreconf autotools-dev autoconf-archive doxygen\
                     graphviz libasound2-dev libtool libjpeg-dev libudev-dev libx11-dev\
                     pkg-config udev make gcc git python3-yaml python3-ply python3-jinja2\
                     ninja-build pkg-config libgnutls28-dev openssl libevent-dev g++ python3-pip

# Install recent version of meson
python3 -m pip install meson --user --upgrade
# Install meson for the root user as well (needed for the libcamera installation)
sudo python3 -m pip install meson --user --upgrade
# Add the meson command to the PATH
export PATH=/home/$USER/.local/bin:$PATH

# Install v4l-utils
git clone https://git.linuxtv.org//v4l-utils.git
cd v4l-utils
./bootstrap.sh
./configure --disable-doxygen-doc --disable-qv4l2 --disable-qvidcap --disable-libdvbv5
make
sudo make install

# Install libcamera
git clone git://linuxtv.org/libcamera.git
cd libcamera
meson build
sudo ninja -C build install

# Make it possible to find the shared libraries
export PKG_CONFIG_PATH=/usr/local/lib/aarch64-linux-gnu:$PKG_CONFIG_PATH
sudo ldconfig
```

##### Check if the sub-devices are detected <a name="camera_subdevices">

If you look into `/dev`, you will find a couple of video related devices, for me it looks like this:
```bash
basti@nanopct4:~$ ls /dev/ | grep "video\|v4l\|media"
media0
media1
media2
v4l
v4l-subdev0
v4l-subdev1
v4l-subdev2
v4l-subdev3
video0
video1
video2
video3
video4
video5
video6
video7
```
But that doesn't help us yet, to find out if all the necessary parts have been set up properly.

This is where the `media-ctl` command kicks in, it's basically an interface to the [media controller API](https://www.kernel.org/doc/html/latest/userspace-api/media/mediactl/media-controller.html), that is used to present complex camera pipelines in form of a graph, where the different entities have pads that are connected with each other through data links.

With `media-ctl -p` you can print out the device topology:
```bash
...
driver          rkisp1
- entity 1: rkisp1_isp (4 pads, 5 links)
...
- entity 6: rkisp1_resizer_mainpath (2 pads, 2 links)
...
- entity 9: rkisp1_resizer_selfpath (2 pads, 2 links)
...
- entity 12: rkisp1_mainpath (1 pad, 1 link)
...
- entity 16: rkisp1_selfpath (1 pad, 1 link)
...
- entity 20: rkisp1_stats (1 pad, 1 link)
...
- entity 24: rkisp1_params (1 pad, 1 link)
...
- entity 28: ov13850 1-0010 (1 pad, 1 link)
...
```
In this reduced example, you can see that the camera pipeline consists of an ISP (Image Signal Processor), which processes the captured frames from the camera (ov13850) and provides two entities, that write the refined frames to memory after resizing them (mainpath & selfpath(preview)). Additionally, it contains a stats and a params video node, which are used together with special algorithms (3A), to configure the parameters of the ISP based on the statistics data it spills out.

Your output should look similar to mine, if you want to proceed with the next steps.

##### Build a camera pipeline <a name="camera_pipeline">

We can manually configure a camera pipeline using the `media-ctl` command. For example, the following command activates the link from the 2nd pad of the ISP to pad 0 of the mainpath entity:
```bash
"media-ctl" "--device" "platform:rkisp1" "--links" "'rkisp1_isp':2 -> 'rkisp1_resizer_mainpath':0 [1]"
```

Here is an example of a complete pipeline with explaination, the order of instruction matters:
```bash
# recent all current links
media-ctl --device "platform:rkisp1" --reset
# connect pad 0 (sink) of the ISP with pad 0 of the camera and enable the link
media-ctl --device "platform:rkisp1" --links "'ov13850 1-0010':0 -> 'rkisp1_isp':0 [1]"
# create a link between the selfpath (preview) and the ISP output on pad 2 (source), but keep it deactivated
media-ctl --device "platform:rkisp1" --links "'rkisp1_isp':2 -> 'rkisp1_resizer_selfpath':0 [0]"
# create a link between the mainpath and the ISP output on pad 2 (source) and enable the link
media-ctl --device "platform:rkisp1" --links "'rkisp1_isp':2 -> 'rkisp1_resizer_mainpath':0 [1]"

# Set the video format on the camera (this is very dependent on your camera)
media-ctl --device "platform:rkisp1" --set-v4l2 '"ov13850 1-0010":0 [fmt:SBGGR10_1X10/2112x1568]'
# Set the input video format for the ISP, this must match the video format of the camera, crop it down to 1920x1080
media-ctl --device "platform:rkisp1" --set-v4l2 '"rkisp1_isp":0 [fmt:SBGGR10_1X10/2112x1568 crop: (0,0)/1920x1080]'
# Set the output video format of the ISP, the maximum size was propagated from the sink pad, and the format size is taken from the crop format
media-ctl --device "platform:rkisp1" --set-v4l2 '"rkisp1_isp":2 [fmt:YUYV8_2X8/1920x1080 crop: (0,0)/1920x1080]'

# Set the input format for the mainpath resizer
media-ctl --device "platform:rkisp1" --set-v4l2 '"rkisp1_resizer_mainpath":0 [fmt:YUYV8_2X8/1920x1080]'
# Set the output format for the mainpath resizer
media-ctl --device "platform:rkisp1" --set-v4l2 '"rkisp1_resizer_mainpath":1 [fmt:YUYV8_2X8/1280x720]'

# Configure the format at the mainpath DMA-engine, which is the point that is accessed by user-space
v4l2-ctl --media-bus-info "platform:rkisp1" --device "rkisp1_mainpath" --set-fmt-video "width=1280,height=720,pixelformat=422P"
```

Check the output of `media-ctl -p` to check if the entities were set up properly.

##### Make a test capture <a name="test_capture">

With a fully configured pipeline, we can now try to make a little test recording to memory only.

```bash
# Test stream
v4l2-ctl --media-bus-info "platform:rkisp1" --device "rkisp1_mainpath" --stream-mmap --stream-count=10
```

In case your pipeline is not configured correctly (when there is a mismatch between two linked pads), you will get the following error:
```bash
VIDIOC_STREAMON returned -1 (Broken pipe)
```

And if it worked you will see something like this:
```bash
<<<<<<<<<<
```

##### Record to a file and convert to a viewable format <a name="record_to_file_and_convert">

Alright, the camera works as a little bonus, I will now quickly show how to watch the recorded video.  
The application I use for this step is the `cam` command from libcamera, at the moment of writing this, there is no way of working with the statistics data from the ISP to configure the ISP properly with the correct parameters for stuff like *auto white balance*, *exposure*, etc.  
Images recorded with v4l2-ctl will therefore be completely dark and greenish. While those algorithms are not implemented in the libcamera yet, it at least configures the controls of the sensor to make the image a little better, and additionally it is also a lot simpler.  
I do those steps on my laptop as the NanoPC-T4 is configured without a GUI environment, so I wouldn't be able to watch the video.

**NOTICE**: The `cam` command currently doesn't work out of the box with the OV13850 camera, as there is a mismatch of image formats between the camera and the Image Signal Processor (the camera sensor uses a resolution that is bigger than the maximum allowed resolution of the ISP and libcamera can't handle this).
I am currently working on a patch that fixes the issue, the patch is not merged yet, but you can already use it. Just [download](https://patchwork.libcamera.org/patch/10660/mbox/) the patch and apply it to your libcamera tree with: `cd /path/to/libcamera_tree && git am /path/to/patch.patch`. Afterward, build: `ninja -C build` and install `sudo ninja -C build install`.

Here is a small script, which records with the standard settings of libcamera, moves the data to the host, and converts to mp4.
Depends on: `sudo apt-get install ffmpeg mpv`
You can locate the script on the root directory of the project as well.

```bash
#!/bin/bash

#INPUT: [remote-user] [remote-ip-address] [number of frames]

if [ "$#" -ne 3 ]; then
    echo "Usage: {script} [remote-user] [remote-ip] [number of frames to be captured]"
fi

remote_user=$1
ip=$2
remote="ssh $remote_user@$ip"

remote_in=/home/$remote_user/lib_stream.raw
local_in=/home/$USER/lib_stream.raw
local_out=/home/$USER/lib_out.mp4

# Start the recording and move the finished data from the NanoPC-T4 to the host
$remote cam --camera=1 --capture=$3 --file=$remote_in
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
rm $local_out
```

### Additional topics <a name="additonal_topics">

#### Installing additional packages <a name="additional-packages">

As of late, I was not able to build an armbian image using the `PACKAGE_LIST_ADDITIONAL` configuration option within the `userpatches/lib.config` file. [link to forum post](https://forum.armbian.com/topic/16740-debootstrap-base-system-second-stage-failed/)  
The error message that I recieved looks like this:
```bash
[ o.k. ] Installing base system [ Stage 2/2 ]
/bin/bash: warning: setlocale: LC_ALL: cannot change locale (en_US.UTF-8)
W: Failure trying to run:  /sbin/ldconfig
W: See //debootstrap/debootstrap.log for details
[ error ] ERROR in function create_rootfs_cache [ debootstrap.sh:177 ]
[ error ] Debootstrap base system second stage failed 
[ o.k. ] Process terminated 
[ o.k. ] Unmounting [ /home/basti/Kernel/build/.tmp/rootfs-dev-nanopct4-bullseye-no-yes/ ]
[ error ] ERROR in function unmount_on_exit [ image-helpers.sh:66 ]
[ error ] debootstrap-ng was interrupted 
```

I have switched to [Ansible](https://www.ansible.com/) for this job now, I have added my ansible playbook to this project and will briefly explain how it works below.
Install ansible on ubuntu/debian:
```bash
sudo apt-get install ansible
```

In order to install the dependencies and set up a development setup, Ansible requires you to specify the host on which you want to work. Simply add the following line to your `/etc/ansible/hosts` file ([Use the IP address](#boot_the_image) of your NanoPC-T4 and the username of the [created user](#boot_the_image)):
```bash
sudo sh -c "echo '[SBC]\nnanopct4 ansible_host={IP_ADDRESS} ansible_user={REMOTE_USER} ansible_connection=ssh' >> /etc/ansible/hosts"
```
The line above does the following:
- Add a host group `SBC`, which can later be used to perform a certain action on multiple devices at once
- Add a alias `nanopct4` for the ssh-connection to the device with ip address `ansible_host` and the user `ansible_user`.

And now run execute the playbook:  
```bash
# Add your ssh public key to the device
ssh-copy-id {REMOTE_USER}@{IP_ADDRESS}
# Add a ssh key agent and add the ssh key to it
eval $(ssh-agent)
ssh-add
# Run the playbook, with sudo access (-kK), Enter the password of the {REMOTE_USER}
ansible-playbook /path/to/setup_nanopct4.yml -kK
```

Obviously, the Ansible playbook provided within this project is specifically crafted for my needs, but you should be able to adjust it according to your desired outcome.
