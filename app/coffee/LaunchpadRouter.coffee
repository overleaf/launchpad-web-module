LaunchpadController = require './LaunchpadController'
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")

module.exports =
	apply: (webRouter, apiRouter) ->

		webRouter.get "/launchpad", LaunchpadController.launchpad
		webRouter.post "/launchpad/registeradmin", LaunchpadController.registerAdmin

		if AuthenticationController.addEndpointToLoginWhitelist?
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad'
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad/registeradmin'
