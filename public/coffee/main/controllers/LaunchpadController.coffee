define [
	"base",
], (App) ->

	App.controller "LaunchpadController", ($scope, $http, $timeout) ->

		$scope.adminUserExists = window.data.adminUserExists
		$scope.ideJsPath = window.data.ideJsPath
		$scope.authMethod = window.data.authMethod

		$scope.createAdminSuccess = null
		$scope.createAdminError = null

		$scope.statusChecks = {
			ideJs: {status: 'inflight', error: null},
			websocket: {status: 'inflight', error: null}
			healthCheck: {status: 'inflight', error: null}
		}

		$scope.testEmail = {
			emailAddress: ''
			inflight: false
			status: null # | 'ok' | 'success'
		}

		$scope.shouldShowAdminForm = () ->
			!$scope.adminUserExists

		$scope.onCreateAdminSuccess = (response) ->
			{ status } = response
			if status >= 200 && status < 300
				$scope.createAdminSuccess = true

		$scope.onCreateAdminError = () ->
			$scope.createAdminError = true

		$scope.sendTestEmail = () ->
			$scope.testEmail.inflight = true
			$scope.testEmail.status = null
			$http
				.post('/launchpad/send_test_email', {
					email: $scope.testEmail.emailAddress,
					_csrf: window.csrfToken
				})
				.then (response) ->
					{ status } = response
					$scope.testEmail.inflight = false
					if status >= 200 && status < 300
						$scope.testEmail.status = 'ok'
				.catch () ->
					$scope.testEmail.inflight = false
					$scope.testEmail.status = 'error'

		$scope.tryFetchIdeJs = () ->
			$scope.statusChecks.ideJs.status = 'inflight'
			$timeout(
				() ->
					$http
						.get($scope.ideJsPath)
						.then (response) ->
							{ status } = response
							if status >= 200 && status < 300
								$scope.statusChecks.ideJs.status = 'ok'
						.catch (response) ->
							{ status } = response
							$scope.statusChecks.ideJs.status = 'error'
							$scope.statusChecks.ideJs.error = new Error('Http status: ' + status)
				, 1000
			)

		$scope.tryOpenWebSocket = () ->
			$scope.statusChecks.websocket.status = 'inflight'
			$timeout(
				() ->
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

					socket.on 'connectionRejected', (err) ->
						$scope.statusChecks.websocket.status = 'error'
						$scope.statusChecks.websocket.error = err
						$scope.$apply () ->

					socket.on 'connect_failed', (err) ->
						$scope.statusChecks.websocket.status = 'error'
						$scope.statusChecks.websocket.error = err
						$scope.$apply () ->
				, 1000
			)

		$scope.tryHealthCheck = () ->
			$scope.statusChecks.healthCheck.status = 'inflight'
			$http
				.get('/health_check')
				.then (response) ->
					{ status } = response
					if status >= 200 && status < 300
						$scope.statusChecks.healthCheck.status = 'ok'
				.catch (response) ->
					{ status } = response
					$scope.statusChecks.healthCheck.status = 'error'
					$scope.statusChecks.healthCheck.error = new Error('Http status: ' + status)

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
		if $scope.adminUserExists
			$scope.runStatusChecks()
