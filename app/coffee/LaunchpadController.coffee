Path = require 'path'
module.exports = LaunchpadController =

	launchpad: (req, res, next) ->
		res.render Path.resolve(__dirname, "../views/launchpad"), {}
