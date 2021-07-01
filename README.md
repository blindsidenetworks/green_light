# Greenlight

![Coverage
!Status](https://coveralls.io/repos/github/bigbluebutton/greenlight/badge.svg?branch=master)
![Docker Pulls](https://img.shields.io/docker/pulls/bigbluebutton/greenlight.svg)

Greenlight is a simple front-end interface for your BigBlueButton server. At its heart, Greenlight provides a minimalistic web-based application that allows users to:

  * Signup/Login with Google, Office365, OpenID Connect, or through the application itself.
  * Manage your account settings and user preferences.
  * Create and manage your own personal rooms ([BigBlueButton](https://github.com/bigbluebutton/bigbluebutton) sessions).
  * Invite others to your room using a simple URL.
  * View recordings and share them with others.

**This greenlight has the same features as `release-2.8.2.2` of upstream Greenlight. Feel free to contribute.**

## extra Features additional to upstream Greenlight
  * SIP support - with static PIN for each room

## enable SIP support
1. set the `VOICE_BRIDGE_PHONE_NUMBER` environment variable to your SIP telephone number. This value will be displayed in each room.
2. setup the BBB SIP Integration, if you use Scalelite, you can follow the instructions from https://github.com/MBcom/bbb-clustersip.git to setup a central SIP gateway for your BBB cluster
3. Greenlight will generate automatically a static conference PIN for each room and shows it next to the telephone number
![image](https://user-images.githubusercontent.com/27956078/114266534-1bf5d680-99f7-11eb-8fcb-d28435317c8a.png)

Interested? Try Greenlight out on our [demo server](https://demo.bigbluebutton.org/gl)!

Greenlight is also completely configurable. This means you can turn on/off features to make Greenlight fit your specific use case. For more information on Greenlight and its features, see our [documentation](http://docs.bigbluebutton.org/greenlight/gl-install.html).

For a overview of how Greenlight works, checkout our Introduction to Greenlight Video:

[![GreenLight Overview](https://img.youtube.com/vi/Hso8yLzkqj8/0.jpg)](https://youtu.be/Hso8yLzkqj8)

## Installation on a BigBlueButton Server

Greenlight is designed to work on a [BigBlueButton 2.0](https://github.com/bigbluebutton/bigbluebutton) (or later) server.

For information on installing Greenlight, checkout our [Installing Greenlight on a BigBlueButton Server](http://docs.bigbluebutton.org/greenlight/gl-install.html#installing-on-a-bigbluebutton-server) documentation.

## Source Code & Contributing

Greenlight is built using Ruby on Rails. Many developers already know Rails well, and we wanted to create both a full front-end to BigBlueButton but also a reference implementation of how to fully leverage the [BigBlueButton API](http://docs.bigbluebutton.org/dev/api.html).

We invite you to build upon Greenlight and help make it better. See [Contributing to BigBlueButton](http://docs.bigbluebutton.org/support/faq.html#contributing-to-bigbluebutton).

We invite your feedback, questions, and suggests about Greenlight too. Please post them to the [Greenlight mailing list](https://groups.google.com/forum/#!forum/bigbluebutton-greenlight).

To help with organization and consistency, we have implemented a Pull Request template that must be used for all Pull Requests. This template helps ensure that the project maintainers can review all PRs in a timely manner. When creating a Pull Request, please provide as much information as possible.