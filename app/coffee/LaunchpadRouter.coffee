logger = require 'logger-sharelatex'
LaunchpadController = require './LaunchpadController'
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")
AuthorizationMiddleware = require('../../../../app/js/Features/Authorization/AuthorizationMiddleware')

module.exports =
	apply: (webRouter, apiRouter) ->

		logger.log {}, "Init launchpad router"

		webRouter.get "/launchpad", LaunchpadController.launchpadPage
		webRouter.post "/launchpad/register_admin", LaunchpadController.registerAdmin
		webRouter.post "/launchpad/register_ldap_admin", LaunchpadController.registerExternalAuthAdmin('ldap')
		webRouter.post "/launchpad/register_saml_admin", LaunchpadController.registerExternalAuthAdmin('saml')
		webRouter.post "/launchpad/send_test_email", AuthorizationMiddleware.ensureUserIsSiteAdmin, LaunchpadController.sendTestEmail

		if AuthenticationController.addEndpointToLoginWhitelist?
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_admin'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_ldap_admin'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_saml_admin'
