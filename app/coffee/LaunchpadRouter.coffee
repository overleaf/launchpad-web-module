LaunchpadController = require './LaunchpadController'
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")

module.exports =
	apply: (webRouter, apiRouter) ->

		webRouter.get "/launchpad", LaunchpadController.launchpad

		if AuthenticationController.addEndpointToLoginWhitelist?
			AuthenticationController.addEndpointToLoginWhitelist '/launchpad'
