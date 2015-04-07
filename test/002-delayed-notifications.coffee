# Tests if the server component complies to
# https://xmpp.org/extensions/xep-0347.html
#
# This set test delayed notifications for claim function.
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
    name: 'register & unregister'
    level: 'trace'

# global config
thingConn = undefined
ownerConn = undefined
chai.should()
assert = chai.assert

describe 'Delayed notificatons: ', ->
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

        thingConn.once 'online', () ->
            log.trace 'Thing is now online.'
            thingConn.send '<presence/>'

            thingConn.once 'stanza', (stanza) ->
                ownerConn = new Client
                    jid: config.owner
                    password: config.password
                    host: config.host
                    port: config.port
                    reconnect: false

                ownerConn.once 'online', () ->
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

    describe 'subscribes to the presence of the registry', ->
        it '', (done) ->
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

    describe 'registers the thing in the registry', ->
        it 'and receives a confirmation', (done) ->
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

    describe 'the thing will be claimed by the owner', ->
        it 'but the thing goes offline first', (done) ->
            thingConn.send "<presence type='unavailable' id='#{ shortId.generate() }'/>"

            defer = Q.defer()

            ready = () ->
                thingConn.end()
                defer.resolve()
                done()

            setTimeout ready, 1000

            return defer.promise

        it 'then the owner sends a claim message', (done) ->
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

                done()

        it 'then the thing comes online again', (done) ->
            thingConn = new Client
                jid: config.thing
                password: config.password
                host: config.host
                port: config.port
                reconnect: false

            thingConn.once 'online', () ->
                setTimeout () ->
                    log.trace 'Thing is now online.'
                    thingConn.send '<presence/>'
                , 1000

                thingConn.once 'stanza', (stanza) ->
                    log.trace "Received message: #{ stanza.toString() }"
                    stanza.name.should.equal 'presence'
                    done()

            thingConn.on 'error', (err) ->
                log.warn err
                done()

        it 'and it receives the claimed message', (done) ->
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


