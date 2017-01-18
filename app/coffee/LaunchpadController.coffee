Settings = require 'settings-sharelatex'
Path = require "path"
Url = require "url"
logger = require "logger-sharelatex"
metrics = require "metrics-sharelatex"
ReferalAllocator = require "../../../../app/js/Features/Referal/ReferalAllocator"
UserRegistrationHandler = require("../../../../app/js/Features/User/UserRegistrationHandler")
SubscriptionDomainHandler = require("../../../../app/js/Features/Subscription/SubscriptionDomainHandler")
EmailHandler = require("../../../../app/js/Features/Email/EmailHandler")
EmailBuilder = require("../../../../app/js/Features/Email/EmailBuilder")
PersonalEmailLayout = require("../../../../app/js/Features/Email/Layouts/PersonalEmailLayout")
_ = require "underscore"
UserHandler = require("../../../../app/js/Features/User/UserHandler")
UserGetter = require("../../../../app/js/Features/User/UserGetter")
User = require("../../../../app/js/models/User").User
UserSessionsManager = require("../../../../app/js/Features/User/UserSessionsManager")
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")


module.exports = LaunchpadController =

	_getAuthMethod: () ->
		if Settings.ldap
			'ldap'
		else if Settings.saml
			'saml'
		else
			'local'

	launchpad: (req, res, next) ->
		# TODO: check if we're using external auth?
		#   * how does all this work with ldap and saml?
		sessionUser = AuthenticationController.getSessionUser(req)
		authMethod = LaunchpadController._getAuthMethod()
		LaunchpadController._atLeastOneAdminExists (err, adminUserExists) ->
			if err?
				return next(err)
			if !sessionUser
				if !adminUserExists
					res.render Path.resolve(__dirname, "../views/launchpad"), {adminUserExists, authMethod}
				else
					AuthenticationController._redirectToLoginPage(req, res)
			else
				UserGetter.getUser sessionUser._id, {isAdmin: 1}, (err, user) ->
					if err?
						return next(err)
					if user && user.isAdmin
						res.render Path.resolve(__dirname, "../views/launchpad"), {adminUserExists, authMethod}
					else
						res.redirect '/restricted'

	_atLeastOneAdminExists: (callback=(err, exists)->) ->
		UserGetter.getUser {isAdmin: true}, {_id: 1, isAdmin: 1}, (err, user) ->
			if err?
				return callback(err)
			return callback(null, user?)

	sendTestEmail: (req, res, next) ->
		email = req.body.email
		if !email
			logger.log {}, "no email address supplied"
			return res.sendStatus(400)
		logger.log {email}, "sending test email"
		emailOptions = {to: email}
		EmailHandler.sendEmail "testEmail", emailOptions, (err) ->
			if err?
				logger.err {email}, "error sending test email"
				return next(err)
			logger.log {email}, "sent test email"
			res.sendStatus(201)

	registerExternalAuthAdmin: (authMethod) ->
		return (req, res, next) ->
			if LaunchpadController._getAuthMethod() != authMethod
				logger.log {authMethod}, "trying to register external admin, but that auth service is not enabled, disallow"
				return res.sendStatus(403)
			email = req.body.email
			if !email
				logger.log {authMethod}, "no email supplied, disallow"
				return res.sendStatus(400)

			logger.log {email}, "attempted register first admin user"
			LaunchpadController._atLeastOneAdminExists (err, exists) ->
				if err?
					return next(err)

				if exists
					logger.log {email}, "already have at least one admin user, disallow"
					return res.sendStatus(403)

				body = {
					email: email
					password: 'password_here'
					first_name: email
					last_name: ''
				}
				logger.log {body, authMethod}, "creating admin account for specified external-auth user"

				UserRegistrationHandler.registerNewUser body, (err, user) ->
					if err?
						logger.err {err, email, authMethod}, "error with registerNewUser"
						return next(err)

					User.update {_id: user._id}, {$set: {isAdmin: true}}, (err) ->
						if err?
							logger.err {user_id: user._id, err}, "error setting user to admin"
							return next(err)

						AuthenticationController._setRedirectInSession(req, '/launchpad')
						logger.log {email, user_id: user._id, authMethod}, "created first admin account"

						return res.json {redir: '/launchpad'}

	registerSamlAdmin: (req, res, next) ->
		if LaunchpadController._getAuthMethod() != 'saml'
			logger.log {}, "trying to register saml admin but saml is not enabled, disallow"
			return res.sendStatus(403)
		res.sendStatus(201)

	registerAdmin: (req, res, next) ->
		email = req.body.email
		if !email
			logger.log {}, "no email supplied, disallow"
			return res.sendStatus(400)

		logger.log {email}, "attempted register first admin user"
		LaunchpadController._atLeastOneAdminExists (err, exists) ->
			if err?
				return next(err)

			if exists
				logger.log {email: req.body.email}, "already have at least one admin user, disallow"
				return res.sendStatus(403)

			UserRegistrationHandler.registerNewUser req.body, (err, user)->
				verifyLink = SubscriptionDomainHandler.getDomainLicencePage(user)
				redir = verifyLink or AuthenticationController._getRedirectFromSession(req) or "/project"
				if err? and err?.message == "EmailAlreadyRegistered"
					# TODO: this is an error, return error thing
					return res.sendStatus(400)
				else if err?
					next(err)
				else
					metrics.inc "user.register.success"
					ReferalAllocator.allocate req.session.referal_id, user._id, req.session.referal_source, req.session.referal_medium

					EmailHandler.sendEmail "welcome", {
						first_name:user.first_name
						to: user.email
					}, () ->

					logger.log {user_id: user._id}, "making user an admin"

					User.update {_id: user._id}, {$set: {isAdmin: true}}, (err) ->
						if err?
							logger.err {user_id: user._id, err}, "error setting user to admin"
							return next(err)

						logger.log {email, user_id: user._id}, "created first admin account"
						res.json
							redir: ''
							id: user._id.toString()
							first_name: user.first_name
							last_name: user.last_name
							email: user.email
							created: Date.now()
