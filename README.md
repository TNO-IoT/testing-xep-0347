# Testing XEP-0347

A test suite to test a XEP-0347 IoT discovery component.

## Setup the pre-requests for running the tests

The test suite is build in [coffeescript](http://coffeescript.org) and needs to have coffeescript installed to run. Coffeescript compiles to javascript hence to be able to run coffeescript you need to have [nodejs](http://nodejs.org) installed on your system.

* Install [nodejs](http://nodejs.org)
* Install coffeescript via the node package manager: `npm install coffee-script -g`
* Install the grunt build environment: `npm install grunt-cli -g`
* Install the project dependencies: `npm install`

## Configure the tests

* Edit the file [config.coffee](test/helpers/config.coffee) to reflect your configuration.

## Run instructions

The tests are setup to take the address of the XMPP server you are using for testing from an environment variable called `XMPP_HOST`.

You can run the tests in a single command by issuing:

* `XMPP_HOST=<your hostname or IP address> grunt mochaTest |node_modules/bunyan/bin/bunyan`

## License

This code is available under a **MIT License** which means that you can basically do anything you want with this code as long as you provide attribution back to us and don’t hold us liable.

