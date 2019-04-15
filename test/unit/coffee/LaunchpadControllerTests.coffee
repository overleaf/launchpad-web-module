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
			"../../../overleaf-integration/app/js/SharelatexAuth/SharelatexAuthController":
				@SharelatexAuthController = {}

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
			beforeEach ->
				@user =
					_id: 'abcd'
					email: 'abcd@example.com'
				@AuthenticationController.getSessionUser = sinon.stub().returns @user
				@_atLeastOneAdminExists.callsArgWith(0, null, true)
				@res.render = sinon.stub()
				@res.redirect = sinon.stub()

			describe 'when the user is an admin', ->
				beforeEach ->
					@UserGetter.getUser = sinon.stub().callsArgWith(2, null, {isAdmin: true})
					@LaunchpadController.launchpadPage(@req, @res, @next)

				it 'should render the launchpad page', ->
					viewPath = require('path').join __dirname, "../../../app/views/launchpad"
					@res.render.callCount.should.equal 1
					@res.render.calledWith(viewPath, {adminUserExists: true, authMethod: 'local'}).should.equal true

			describe 'when the user is not an admin', ->
				beforeEach ->
					@UserGetter.getUser = sinon.stub().callsArgWith(2, null, {isAdmin: false})
					@LaunchpadController.launchpadPage(@req, @res, @next)

				it 'should redirect to restricted page', ->
					@res.redirect.callCount.should.equal 1
					@res.redirect.calledWith('/restricted').should.equal true


	describe '_atLeastOneAdminExists', ->

		describe 'when there are no admins', ->
			beforeEach ->
				@UserGetter.getUser = sinon.stub().callsArgWith(2, null, null)

			it 'should callback with false', (done) ->
				@LaunchpadController._atLeastOneAdminExists (err, exists) =>
					expect(err).to.equal null
					expect(exists).to.equal false
					done()

		describe 'when there are some admins', ->
			beforeEach ->
				@UserGetter.getUser = sinon.stub().callsArgWith(2, null, {_id: 'abcd'})

			it 'should callback with true', (done) ->
				@LaunchpadController._atLeastOneAdminExists (err, exists) =>
					expect(err).to.equal null
					expect(exists).to.equal true
					done()

		describe 'when getUser produces an error', ->
			beforeEach ->
				@UserGetter.getUser = sinon.stub().callsArgWith(2, new Error('woops'))

			it 'should produce an error', (done) ->
				@LaunchpadController._atLeastOneAdminExists (err, exists) =>
					expect(err).to.not.equal null
					expect(err).to.be.instanceof Error
					expect(exists).to.equal undefined
					done()


	describe 'sendTestEmail', ->

		beforeEach ->
			@EmailHandler.sendEmail = sinon.stub().callsArgWith(2, null)
			@req.body.email = 'someone@example.com'
			@res.sendStatus = sinon.stub()
			@next = sinon.stub()

		it 'should produce a 201 response', ->
			@LaunchpadController.sendTestEmail @req, @res, @next
			@res.sendStatus.callCount.should.equal 1
			@res.sendStatus.calledWith(201).should.equal true

		it 'should not call next with an error', ->
			@LaunchpadController.sendTestEmail @req, @res, @next
			@next.callCount.should.equal 0

		it 'should have called sendEmail', ->
			@LaunchpadController.sendTestEmail @req, @res, @next
			@EmailHandler.sendEmail.callCount.should.equal 1
			@EmailHandler.sendEmail.calledWith('testEmail').should.equal true

		describe 'when sendEmail produces an error', ->
			beforeEach ->
				@EmailHandler.sendEmail = sinon.stub().callsArgWith(2, new Error('woops'))

			it 'should call next with an error', ->
				@LaunchpadController.sendTestEmail @req, @res, @next
				@next.callCount.should.equal 1
				expect( @next.lastCall.args[0] ).to.be.instanceof Error

		describe 'when no email address is supplied', ->
			beforeEach ->
				@req.body.email = undefined

			it 'should produce a 400 response', ->
				@LaunchpadController.sendTestEmail @req, @res, @next
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(400).should.equal true


	describe 'registerAdmin', ->
		beforeEach ->
			@_atLeastOneAdminExists = sinon.stub(@LaunchpadController, '_atLeastOneAdminExists')

		afterEach ->
			@_atLeastOneAdminExists.restore()

		describe 'when all goes well', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, null, @user)
				@User.update = sinon.stub().callsArgWith(2, null)
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should send back a json response', ->
				@res.json.callCount.should.equal 1
				expect(@res.json.lastCall.args[0].email).to.equal @email

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({email: @email, password: @password}).should.equal true

			it 'should have updated the user to make them an admin', ->
				@User.update.callCount.should.equal 1
				@User.update.calledWith({_id: @user._id}, {$set: {isAdmin: true}}).should.equal true

			it 'should have set a redirect in session', ->
				@AuthenticationController.setRedirectInSession.callCount.should.equal 1
				@AuthenticationController.setRedirectInSession.calledWith(@req, '/launchpad').should.equal true


		describe 'when no email is supplied', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = undefined
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should send a 400 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(400).should.equal true

			it 'should not check for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 0

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when no password is supplied', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@password = undefined
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should send a 400 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(400).should.equal true

			it 'should not check for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 0

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when there are already existing admins', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, true)
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should send a 403 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(403).should.equal true

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when checking admins produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, new Error('woops'))
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when registerNewUser produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, new Error('woops'))
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({email: @email, password: @password}).should.equal true

			it 'should not call update', ->
				@User.update.callCount.should.equal 0

		describe 'when user update produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, null, @user)
				@User.update = sinon.stub().callsArgWith(2, new Error('woops'))
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({email: @email, password: @password}).should.equal true

		describe 'when overleaf', ->
			beforeEach ->
				@Settings.overleaf = {one: 1}
				@Settings.createV1AccountOnLogin = true
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@password = 'a_really_bad_password'
				@req.body.email = @email
				@req.body.password = @password
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, null, @user)
				@User.update = sinon.stub().callsArgWith(2, null)
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@SharelatexAuthController._createBackingAccountIfNeeded = sinon.stub().callsArgWith(2, null)
				@UserGetter.getUser = sinon.stub().callsArgWith(1, null, {_id: '1234'})
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerAdmin(@req, @res, @next)

			it 'should send back a json response', ->
				@res.json.callCount.should.equal 1
				expect(@res.json.lastCall.args[0].email).to.equal @email

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({email: @email, password: @password}).should.equal true

			it 'should have created a backing account for the user', ->
				@SharelatexAuthController._createBackingAccountIfNeeded.callCount.should.equal 1

			it 'should have updated the user to make them an admin', ->
				@User.update.calledWith({_id: @user._id}, {$set: {isAdmin: true}}).should.equal true

			it 'should have set a redirect in session', ->
				@AuthenticationController.setRedirectInSession.callCount.should.equal 1
				@AuthenticationController.setRedirectInSession.calledWith(@req, '/launchpad').should.equal true


	describe 'registerExternalAuthAdmin', ->
		beforeEach ->
			@Settings.ldap = {one: 1}
			@_atLeastOneAdminExists = sinon.stub(@LaunchpadController, '_atLeastOneAdminExists')

		afterEach ->
			@_atLeastOneAdminExists.restore()

		describe 'when all goes well', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, null, @user)
				@User.update = sinon.stub().callsArgWith(2, null)
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should send back a json response', ->
				@res.json.callCount.should.equal 1
				expect(@res.json.lastCall.args[0].email).to.equal @email

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({
					email: @email, password: 'password_here', first_name: @email, last_name: ''
				}).should.equal true

			it 'should have updated the user to make them an admin', ->
				@User.update.callCount.should.equal 1
				@User.update.calledWith({_id: @user._id}, {$set: {isAdmin: true}}).should.equal true

			it 'should have set a redirect in session', ->
				@AuthenticationController.setRedirectInSession.callCount.should.equal 1
				@AuthenticationController.setRedirectInSession.calledWith(@req, '/launchpad').should.equal true

		describe 'when the authMethod is invalid', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = undefined
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('NOTAVALIDAUTHMETHOD')(@req, @res, @next)

			it 'should send a 403 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(403).should.equal true

			it 'should not check for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 0

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when no email is supplied', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = undefined
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should send a 400 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(400).should.equal true

			it 'should not check for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 0

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when there are already existing admins', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, true)
				@email = 'someone@example.com'
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should send a 403 response', ->
				@res.sendStatus.callCount.should.equal 1
				@res.sendStatus.calledWith(403).should.equal true

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when checking admins produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, new Error('woops'))
				@email = 'someone@example.com'
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub()
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.sendStatus = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should not call registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 0

		describe 'when registerNewUser produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, new Error('woops'))
				@User.update = sinon.stub()
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({
					email: @email, password: 'password_here', first_name: @email, last_name: ''
				}).should.equal true

			it 'should not call update', ->
				@User.update.callCount.should.equal 0

		describe 'when user update produces an error', ->
			beforeEach ->
				@_atLeastOneAdminExists.callsArgWith(0, null, false)
				@email = 'someone@example.com'
				@req.body.email = @email
				@user =
					_id: 'abcdef'
					email: @email
				@UserRegistrationHandler.registerNewUser = sinon.stub().callsArgWith(1, null, @user)
				@User.update = sinon.stub().callsArgWith(2, new Error('woops'))
				@AuthenticationController.setRedirectInSession = sinon.stub()
				@res.json = sinon.stub()
				@next = sinon.stub()
				@LaunchpadController.registerExternalAuthAdmin('ldap')(@req, @res, @next)

			it 'should call next with an error', ->
				@next.callCount.should.equal 1
				expect(@next.lastCall.args[0]).to.be.instanceof Error

			it 'should have checked for existing admins', ->
				@_atLeastOneAdminExists.callCount.should.equal 1

			it 'should have called registerNewUser', ->
				@UserRegistrationHandler.registerNewUser.callCount.should.equal 1
				@UserRegistrationHandler.registerNewUser.calledWith({
					email: @email, password: 'password_here', first_name: @email, last_name: ''
				}).should.equal true
