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

		$scope.testEmail = {
			emailAddress: ''
			inflight: false
			status: null # | 'ok' | 'success'
		}

		$scope.shouldShowAdminForm = () ->
			!$scope.adminUserExists

		$scope.onCreateAdminSuccess = (data, status) ->
			if status == 200
				$scope.createAdminSuccess = true
				# setTimeout(
				# 	() ->
				# 		window.location.reload(false)
				# , 2000)

		$scope.sendTestEmail = () ->
			$scope.testEmail.inflight = true
			$scope.testEmail.status = null
			console.log ">> sending test email"
			$http
				.post('/launchpad/send_test_email', {
					email: $scope.testEmail.emailAddress,
					_csrf: window.csrfToken
				})
				.success (data, status, headers) ->
					$scope.testEmail.inflight = false
					if status >= 200 && status < 300
						console.log ">> sent email"
						$scope.testEmail.status = 'ok'
				.error (data, status, headers) ->
					$scope.testEmail.inflight = false
					console.log ">> email error"
					$scope.testEmail.status = 'error'

		$scope.tryFetchIdeJs = () ->
			$scope.statusChecks.ideJs.status = 'inflight'
			$http
				.get($scope.ideJsPath)
				.success (data, status, headers) ->
					if status >= 200 && status < 300
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
			# $timeout(
			# 	() ->
			# 		$scope.tryHealthCheck()
			# 	, 12000
			# )

		# kick off the status checks on load
		if $scope.adminUserExists
			$scope.runStatusChecks()
