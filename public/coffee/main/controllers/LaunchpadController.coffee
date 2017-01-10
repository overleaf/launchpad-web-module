define [
	"base",
], (App) ->

	App.controller "LaunchpadController", ($scope, $http, $timeout) ->

		$scope.adminUserExists = window.data.adminUserExists
		$scope.ideJsPath = window.data.ideJsPath
		$scope.createAdminSuccess = null

		$scope.statusChecks = {
			ideJs: {status: 'inflight', error: null},
			websocket: {status: 'inflight', error: null}
			healthCheck: {status: 'inflight', error: null}
		}

		$scope.onSuccess = (data, status) ->
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
						$scope.statusChecks.ideJs.error = new Error('Http status: ' + status)

		$scope.tryOpenWebSocket = () ->
			$scope.statusChecks.websocket.status = 'inflight'
			if !io?
				$scope.statusChecks.websocket.status = 'error'
				$scope.statusChecks.websocket.error = 'socket.io not loaded'
				return
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

		$scope.tryHealthCheck = () ->
			$scope.statusChecks.healthCheck.status = 'inflight'
			$http
				.get('/health_check')
				.success (data, status, headers) ->
					if status >= 200 && status < 300
						$scope.statusChecks.healthCheck.status = 'ok'
				.error (data, status, headers) ->
					console.log ">> failed"
					console.log data
					console.log status
					$scope.statusChecks.healthCheck.status = 'error'
					$scope.statusChecks.healthCheck.error = new Error('Http status: ' + status)

		$scope.runStatusChecks = () ->
			$timeout(
				() ->
					$scope.tryFetchIdeJs()
				, 4000
			)
			$timeout(
				() ->
					$scope.tryOpenWebSocket()
				, 8000
			)
			$timeout(
				() ->
					$scope.tryHealthCheck()
				, 12000
			)

		# kick off the status checks on load
		$scope.runStatusChecks()
