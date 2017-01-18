LaunchpadController = require './LaunchpadController'
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")
AuthorizationMiddlewear = require('../../../../app/js/Features/Authorization/AuthorizationMiddlewear')

module.exports =
	apply: (webRouter, apiRouter) ->

		webRouter.get "/launchpad", LaunchpadController.launchpad
		webRouter.post "/launchpad/register_admin", LaunchpadController.registerAdmin
		webRouter.post "/launchpad/register_ldap_admin", LaunchpadController.registerExternalAuthAdmin('ldap')
		webRouter.post "/launchpad/register_saml_admin", LaunchpadController.registerExternalAuthAdmin('saml')
		webRouter.post "/launchpad/send_test_email", AuthorizationMiddlewear.ensureUserIsSiteAdmin, LaunchpadController.sendTestEmail

		if AuthenticationController.addEndpointToLoginWhitelist?
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_admin'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_ldap_admin'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_saml_admin'
