LaunchpadController = require './LaunchpadController'
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")

module.exports =
	apply: (webRouter, apiRouter) ->

		webRouter.get "/launchpad", LaunchpadController.launchpad
		webRouter.post "/launchpad/register_admin", LaunchpadController.registerAdmin
		webRouter.post "/launchpad/send_test_email", LaunchpadController.sendTestEmail

		if AuthenticationController.addEndpointToLoginWhitelist?
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/register_admin'
