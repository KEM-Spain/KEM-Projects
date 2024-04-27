# pyts

    <!--README-->

    `pyts` is a Python utility that provides a torrent search frontend to Deluge

## Features

    - The ability to search 3 engines for torrent files: Pirate Bay, Lime, and EZTV
    - Search history

## Installation

    make install - installs to /usr/local/bin

### Dependencies

    Python3 
    Deluge

    sudo apt-get install python3-bs4
    sudo apt-get install python3-gi
    sudo apt-get install python3-gi-cairo
    sudo apt-get install deluge

## Usage

    Usage: pyts [-h] [-e <ENGINE>] [<TITLE>]

    Options:-h: help
            -e: <ENGINE>

    DESC: Search engine for Deluge
          Enter <TITLE> via gui or on the command line

    SUPPORTED ENGINES:
        pb   : The Pirate Bay (default)
        lime : Lime Torrents
        eztv : Eztv Torrent

## Customization

    This utility was designed for the Ubuntu environment
    However, with minor modifications, it can be tailored to run in others as well

    Additionally, Deluge is easily swapped for any torrent client provided the system
    call is suitably modified

    <!--END README-->
