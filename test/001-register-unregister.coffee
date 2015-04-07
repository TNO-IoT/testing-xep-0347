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
    name: '001 - register & unregister'
    level: 'trace'

# global config
thingConn = undefined
ownerConn = undefined
chai.should()
assert = chai.assert

describe 'Registering and unregistering a Thing', ->
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

    describe 'register the thing in the registry', ->
        it 'sends registration message and receives a confirmation', (done) ->
            log.trace 'Sending register message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <register xmlns='urn:xmpp:iot:discovery'>
                      <str name='SN' value='394872348732948723'/>
                      <str name='MAN' value='www.ktc.se'/>
                      <str name='MODEL' value='IMC'/>
                      <num name='V' value='1.2'/>
                      <str name='KEY' value='4857402340298342'/>
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

    describe 'the thing is not found yet because it is not claimed', ->
        it 'owner sends a search message', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strEq name='MAN' value='www.ktc.se'/>
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
                done()

    describe 'the thing cannot be updated', ->
        it 'by the thing itself', (done) ->
            message = "<iq type='set'
                to='#{ config.registry }'
                id='#{ shortId.generate() }'>
                   <update xmlns='urn:xmpp:iot:discovery'>
                       <str name='MAN' value='www.servicelab.org'/>
                    </update>
                </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'disowned'
                done()

    describe 'the thing is claimed by the owner', ->
        it 'and the owner sends a claim message', (done) ->
            message = "<iq type='set'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <mine xmlns='urn:xmpp:iot:discovery'>
                      <str name='SN' value='394872348732948723'/>
                      <str name='MAN' value='www.ktc.se'/>
                      <str name='MODEL' value='IMC'/>
                      <num name='V' value='1.2'/>
                      <str name='KEY' value='4857402340298342'/>
                  </mine>
                </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'claimed'
                stanza.children[0].attrs.jid.should.equal config.thing

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.attrs.from.should.equal config.registry
                stanza.attrs.type.should.equal 'set'
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'claimed'
                stanza.children[0].attrs.jid.should.equal config.owner

                thingConn.send "<iq type='result'
                    to='#{ stanza.attrs.from }'
                    id='#{ stanza.attrs.id }'/>"

                done()

    describe 'the thing can be found', ->
        it 'when someone sends a search message', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strEq name='MAN' value='www.ktc.se'/>
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
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                found.children[0].attrs.owner.should.equal config.owner
                done()

    describe 'update of the meta information', ->
        it 'by the thing itself', (done) ->
            message = "<iq type='set'
                to='#{ config.registry }'
                id='#{ shortId.generate() }'>
                   <update xmlns='urn:xmpp:iot:discovery'>
                       <str name='MAN' value='www.servicelab.org'/>
                    </update>
                </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 0
                done()

        it 'by the owner of the thing', (done) ->
            message = "<iq type='set'
                to='#{ config.registry }'
                id='#{ shortId.generate() }'>
                   <update xmlns='urn:xmpp:iot:discovery' jid='#{ config.thing }'>
                       <str name='MODEL' value='ABC'/>
                    </update>
                </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 0
                done()

        it 'should result in updated search results', (done) ->
            message = "<iq type='get'
                   to='#{ config.registry }'
                   id='#{ shortId.generate() }'>
                  <search xmlns='urn:xmpp:iot:discovery' offset='0' maxCount='20'>
                      <strEq name='MAN' value='www.servicelab.org'/>
                      <strEq name='MODEL' value='ABC'/>
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
                found.children[0].name.should.equal 'thing'
                found.children[0].attrs.jid.should.equal config.thing
                found.children[0].attrs.owner.should.equal config.owner
                done()

    describe 'disowning thing', ->
        it 'the owner sends the disown message and receives a confirmation', (done) ->
            log.trace 'sending disown message'

            message = "<iq type='set'
                    to='#{ config.registry }'
                    id='#{ shortId.generate() }'>
                <disown xmlns='urn:xmpp:iot:discovery' jid='#{ config.thing }'/>
            </iq>"


            log.info "Sending message: #{ message }"
            ownerConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'set'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                stanza.children[0].name.should.equal 'disowned'

                response = "<iq type='result' to='#{ stanza.attrs.from }'
                    id='#{ stanza.attrs.id }'/>"
                log.info "Sending response: #{ response }"
                thingConn.send response

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()

        it 'the owner sends the disown and receives failure', (done) ->
            log.trace 'sending disown message'

            message = "<iq type='set'
                    to='#{ config.registry }'
                    id='#{ shortId.generate() }'>
                <disown xmlns='urn:xmpp:iot:discovery' jid='#{ config.thing }'/>
            </iq>"

            log.info "Sending message: #{ message }"
            ownerConn.send message

            ownerConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'error'
                stanza.attrs.from.should.equal config.registry
                assert.lengthOf stanza.children, 1
                error = stanza.children[0]
                error.name.should.equal 'error'
                error.attrs.type.should.equal 'cancel'
                assert.lengthOf error.children, 1
                error.children[0].name.should.equal 'item-not-found'
                done()

    describe 'unregister the thing from the registry', ->
        it 'sends the unregister message and receives a confirmation', (done) ->
            log.trace 'Sending unregister message'
            message = "<iq type='set'
                           to='#{ config.registry }'
                           id='#{ shortId.generate() }'>
                  <unregister xmlns='urn:xmpp:iot:discovery'/>
               </iq>"

            log.info "Sending message: #{ message }"
            thingConn.send message

            thingConn.once 'stanza', (stanza) ->
                log.info "Received message: #{ stanza.toString() }"
                stanza.name.should.equal 'iq'
                stanza.attrs.type.should.equal 'result'
                stanza.attrs.from.should.equal config.registry
                done()

