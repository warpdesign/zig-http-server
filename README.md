# zig-http-server

## Why
I wanted to learn Zig and also wanted to look into HTTP so I decided to write
a very small server as a proof of concept.

## Description
Very very basic proof of concept http-server written as a way to learn Zig.

When I mean very basic, I mean it:

- it only parses and prints out the header list and returns an hardcoded html page
- it also probably does not work with concurrent requests (haven't test yet)
- it's probably as slow as it could be

Also this is not following the good practices so you should not
use this code or server other than for educational purpose! :)

## Requirements
The server has been developed using Zig 0.13.0. As the language is quite
a moving target, this may very well fail to build with a future version.

## How to build

> zig build-exe ./server.zig