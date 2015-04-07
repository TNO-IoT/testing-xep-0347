# Tests if the server component complies to
# https://xmpp.org/extensions/xep-0347.html
#
# This set test some basic functions for registration, claim,
# search, update, disown and unregister functions.
#

ltx = require('node-xmpp-core').ltx
Client = require 'node-xmpp-client'
bunyan = require 'bunyan'
shortId = require 'shortid'
assert = require 'assert'
chai = require 'chai'
Q = require 'q'

config = require './helpers/config'

log = bunyan.createLogger
    name: '004-search-ranges'
    level: 'trace'

# global config
thingConn = undefined
ownerConn = undefined
chai.should()
assert = chai.assert

describe 'Search ranges of meta-data to find a Thing', ->
    this.timeout 10000
    before () ->
        defer = Q.defer()

        log.trace 'Connecting to XMPP server'
        thingConn = new Client
            jid: config.thing
            password: config.password
            host: config.host
            port: config.port
            reconnect: false

        thingConn.on 'online', () ->
            log.trace 'Thing is now online.'
            thingConn.send '<presence/>'

            thingConn.once 'stanza', (stanza) ->
                ownerConn = new Client
                    jid: config.owner
                    password: config.password
                    host: config.host
                    port: config.port
                    reconnect: false

                ownerConn.on 'online', () ->
                    log.trace 'Owner is now online.'
                    defer.resolve()

        thingConn.on 'error', (err) ->
            log.warn err
            defer.reject()

        return defer.promise

    after () ->
        defer = Q.defer()

        log.trace 'Unsubscribing from presence!'
        thingConn.send "<presence type='unsubscribe' to='#{ config.registry }'/>"

        ready = () ->
            thingConn.end()
            defer.resolve()

        setTimeout ready, 100

        ownerConn.end()
        return defer.promise

    describe 'subscribe to the presence of the registry', ->
        it 'sends the presence subscribtion', (done) ->
            log.trace 'Sending presence subscription'
            message = "<presence type='subscribe'
                to='#{ config.registry }'
                id='#{ shortId.generate() }'/>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'presence'
                stanza.attrs.type.should.equal 'subscribe'
                stanza.attrs.from.should.equal config.registry

                answer = "<presence type='subscribed'
                    to='#{ config.registry }'
                    id='#{ shortId.generate() }'/>"

                log.info "Sending message: #{ answer }"
                thingConn.send answer

                done()

    describe 'register the first thing in the registry', ->
        it 'sends registration message and receives a confirmation', (done) ->
            log.trace 'Sending register message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <register xmlns='urn:xmpp:iot:discovery' sourceId='testing'
                            nodeId='1' selfOwned='true'>
                      <str name='SN' value='394872348732948723'/>
                      <str name='MAN' value='www.ktc.se'/>
                      <str name='MODEL' value='B'/>
                      <num name='V' value='1.2'/>
                      <str name='KEY' value='ABC'/>
                  </register>
               </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()

    describe 'register the second thing in the registry', ->
        it 'sends registration message and receives a confirmation', (done) ->
            log.trace 'Sending register message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <register xmlns='urn:xmpp:iot:discovery'
                            sourceId='testing' nodeId='2' selfOwned='true'>
                      <str name='SN' value='394872348732948723'/>
                      <str name='MAN' value='www.ktc.com'/>
                      <str name='MODEL' value='C'/>
                      <num name='V' value='2.0'/>
                      <str name='KEY' value='ABC'/>
                  </register>
               </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()

    describe 'when someone searches with a string range', ->
        it 'can find 2 things', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strRange name='MODEL' min='A' max='C'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'only finds 1 thing', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strRange name='MODEL' min='A' max='C' maxIncluded='false'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '1'
                done()

    describe 'when someone searches outside of a string range', ->
        it 'can find 2 things', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strNRange name='MODEL' min='C' max='E' minIncluded='false'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'only finds 1 thing', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strNRange name='MODEL' min='0' max='B'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '2'
                done()

    describe 'when someone searches with a number range', ->
        it 'can find 2 things', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <numRange name='V' min='1.0' max='2.0'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'only finds 1 thing', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <numRange name='V' min='1.2' max='2.0' minIncluded='false'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '2'
                done()

    describe 'when someone searches outside of a number range', ->
        it 'can find 2 things', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <numNRange name='V' min='2.0' max='3.0' minIncluded='false'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'only finds 1 thing', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <numNRange name='V' min='0' max='1.2'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '2'
                done()

    describe 'when someone searches with a string mask', ->
        it 'can find 2 things', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strMask name='MAN' value='www.ktc.*' wildcard='*'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'can find 2 things with another wildcard', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strMask name='MAN' value='www.ktc#' wildcard='#'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 2
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                done()

        it 'only finds 1 thing', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strMask name='MAN' value='www.ktc.se' wildcard='*'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '1'
                done()

        it 'only finds 1 thing with another wildcard', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strMask name='MAN' value='*.ktc.com' wildcard='*'/>
                  </search>
               </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'found'
                found = stanza.children[0]
                assert.lengthOf found.children, 1
                found.children[0].attrs.nodeId.should.equal '2'
                done()

     describe 'unregister the first thing from the registry', ->
        it 'sends the unregister message and receives a confirmation', (done) ->
            log.trace 'Sending unregister message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <unregister xmlns='urn:xmpp:iot:discovery' sourceId='testing' nodeId='1'/>
               </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()

     describe 'unregister the second thing from the registry', ->
        it 'sends the unregister message and receives a confirmation', (done) ->
            log.trace 'Sending unregister message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <unregister xmlns='urn:xmpp:iot:discovery' sourceId='testing' nodeId='2'/>
               </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()


