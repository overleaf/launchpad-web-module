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

	launchpad: (req, res, next) ->
		# TODO: check if we're using external auth?
		#   * how does all this work with ldap and saml?
		LaunchpadController._atLeastOneAdminExists (err, exists) ->
			if err?
				return next(err)
			res.render Path.resolve(__dirname, "../views/launchpad"), {adminUserExists: exists}

	_atLeastOneAdminExists: (callback=(err, exists)->) ->
		UserGetter.getUser {isAdmin: true}, {_id: 1, isAdmin: 1}, (err, user) ->
			console.log ">>", user?
			if err?
				return callback(err)
			return callback(null, user?)

	registerAdmin: (req, res, next) ->
		logger.log email: req.body.email, "attempted register first admin user"
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

						UserHandler.populateGroupLicenceInvite(user, ->)

						req.login user, (err) ->
							return callback(error) if error?
							req.session.justRegistered = true
							# copy to the old `session.user` location, for backward-comptability
							req.session.user = req.session.passport.user
							AuthenticationController._clearRedirectFromSession(req)
							UserSessionsManager.trackSession(user, req.sessionID, () ->)

							res.json
								redir: redir
								id: user._id.toString()
								first_name: user.first_name
								last_name: user.last_name
								email: user.email
								created: Date.now()
