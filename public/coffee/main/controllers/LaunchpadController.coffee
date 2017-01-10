define [
	"base",
], (App) ->

	App.controller "LaunchpadController", ($scope, $http, $timeout) ->
		console.log ">> launchpad"

		$scope.adminUserExists = window.data.adminUserExists
		$scope.ideJsPath = window.data.ideJsPath
		$scope.createAdminSuccess = null

		$scope.statusChecks = {
			ideJs: {status: 'inflight', error: null},
			websocket: {status: 'inflight', error: null}
		}

		$scope.onSuccess = (data, status) ->
			console.log ">> here", data, status
			if status == 200
				$scope.createAdminSuccess = true

		$scope.tryFetchIdeJs = () ->
			$scope.statusChecks.ideJs.status = 'inflight'
			$http
				.get($scope.ideJsPath)
				.success (data, status, headers) ->
					console.log '>> ', status
					if status >= 200 && status < 300
						console.log ">> here, yeah"
						$scope.statusChecks.ideJs.status = 'ok'
				.error (data, status, headers) ->
						$scope.statusChecks.ideJs.status = 'error'
						$scope.statusChecks.ideJs.error = new Error('status code ' + status)

		$scope.tryOpenWebSocket = () ->
			$scope.statusChecks.websocket.status = 'inflight'
			socket = io.connect null,
				reconnect: false
				'connect timeout': 30 * 1000
				"force new connection": true

			socket.on 'connectionAccepted', () ->
				$scope.statusChecks.websocket.status = 'ok'
				$scope.$apply () ->
				console.log ">> accepted"

			socket.on 'connectionRejected', (err) ->
				$scope.statusChecks.websocket.status = 'error'
				$scope.statusChecks.websocket.error = err
				$scope.$apply () ->
				console.log ">> rejected"

			socket.on 'connect_failed', (err) ->
				$scope.statusChecks.websocket.status = 'error'
				$scope.statusChecks.websocket.error = err
				$scope.$apply () ->
				console.log ">> failed"

		$scope.runStatusChecks = () ->
			$timeout(
				() ->
					$scope.tryFetchIdeJs()
				, 1000
			)
			$timeout(
				() ->
					$scope.tryOpenWebSocket()
				, 2000
			)

		# kick off the status checks on load
		$scope.runStatusChecks()
