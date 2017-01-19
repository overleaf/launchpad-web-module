SandboxedModule = require('sandboxed-module')
assert = require('assert')
require('chai').should()
expect = require('chai').expect
sinon = require('sinon')
ObjectId = require("mongojs").ObjectId
modulePath = require('path').join __dirname, '../../../app/js/LaunchpadController.js'

describe 'LaunchpadController', ->
	beforeEach ->

		@user =
			_id:"323123"
			first_name: 'fn'
			last_name: 'ln'
			save: sinon.stub().callsArgWith(0)

		@User = {}
		@LaunchpadController = SandboxedModule.require modulePath, requires:
			"settings-sharelatex": @Settings = {}
			"logger-sharelatex": @Logger =
				log: ()->
				err: ()->
				error: ()->
			"metrics-sharelatex": @Metrics = {}
			"../../../../app/js/Features/User/UserRegistrationHandler": @UserRegistrationHandler = {}
			"../../../../app/js/Features/Email/EmailHandler": @EmailHandler = {}
			"../../../../app/js/Features/User/UserGetter": @UserGetter = {}
			"../../../../app/js/models/User": {User: @User}
			"../../../../app/js/Features/Authentication/AuthenticationController": @AuthenticationController = {}

		@email = "bob@smith.com"

		@req =
			query: {}
			body: {}
			session: {}

		@res =
			render: sinon.stub()
			send: sinon.stub()
			sendStatus: sinon.stub()

		@next = sinon.stub()

	describe "launchpadPage", ->
		beforeEach ->
			@_atLeastOneAdminExists = sinon.stub(@LaunchpadController, '_atLeastOneAdminExists')
			@AuthenticationController._redirectToLoginPage = sinon.stub()

		afterEach ->
			@_atLeastOneAdminExists.restore()

		describe 'when the user is not logged in', ->
			beforeEach ->
				@AuthenticationController.getSessionUser = sinon.stub().returns null
				@res.render = sinon.stub()

			describe 'when there are no admins', ->
				beforeEach ->
					@_atLeastOneAdminExists.callsArgWith(0, null, false)
					@LaunchpadController.launchpadPage(@req, @res, @next)

				it 'should render the launchpad page', ->
					viewPath = require('path').join __dirname, "../../../app/views/launchpad"
					@res.render.callCount.should.equal 1
					@res.render.calledWith(viewPath, {adminUserExists: false, authMethod: 'local'}).should.equal true

			describe 'when there is at least one admin', ->
				beforeEach ->
					@_atLeastOneAdminExists.callsArgWith(0, null, true)
					@LaunchpadController.launchpadPage(@req, @res, @next)

				it 'should redirect to login page', ->
					@AuthenticationController._redirectToLoginPage.callCount.should.equal 1

				it 'should not render the launchpad page', ->
					@res.render.callCount.should.equal 0


		describe 'when the user is logged in', ->


			describe 'when the user is an admin', ->


			describe 'when the user is not an admin', ->
