module.exports = (grunt) ->

    grunt.initConfig

        coffeelint:
            all: ['src/**/*.coffee']
            options:
                configFile: './coffeelint.json'

        mochaTest:
            test:
                options:
                    reporter: 'spec'
                    require: 'coffee-script/register'
                src: [ 'test/**/*.coffee' ]

        watch:
            coffeescript:
                files: ['src/**/*.coffee', 'test/**/*.coffee']
                tasks: ['coffeelint', 'mochaTest']
                options:
                    spawn: false

    grunt.event.on 'watch', (action, filepath) ->
        grunt.config(['coffeelint', 'all'], filepath)

    grunt.loadNpmTasks 'grunt-coffeelint'
    grunt.loadNpmTasks 'grunt-contrib-watch'
    grunt.loadNpmTasks 'grunt-mocha-test'

    grunt.registerTask 'default', ['watch']
