angular.module("perform").controller "LoginCtrl", [
  "$scope"
  "Auth"
  "$state"
  "$stateParams"
  "$location"

  ($scope, Auth, $state, $stateParams, $location) ->

    console.log('Login Ctrl')

    $scope.init = () ->
      $location.url($state.current.url.split('?')[0])

    if $stateParams.auth_error != "401" and not Auth.getStatus()
      $scope.init()
    else if Auth.getStatus()
      $state.transitionTo('landing.home')

    $scope.auth = Auth.auth

    $scope.$watch '$stateParams.auth_error', (newValue, oldValue) ->
      $scope.auth_error = newValue

    $scope.login = (auth) ->

      Auth.login(auth).then (response) ->

        console.log('Auth Status', Auth.getStatus(), Auth.rejectState)

        if (Auth.getStatus()) and Auth.rejectState.length

          console.log('login 1')

          stateName   = Auth.rejectState[0].name

          # Then this is a brand new session (new tab)
          # no need to recover anything
          if stateName is 'landing'
            stateName = 'landing.home'
          stateParams = Auth.rejectState[1]

          Auth.rejectState = []

          console.log("Recovering", stateName, stateParams)
          $state.go(stateName, stateParams)

        else if Auth.getStatus()
          console.log('login 2')

          $state.go('landing.home')
        else
          console.log('XXXXXXXXXXXXXXX FIX ME XXXXXXXXXXXXXXX')
          console.log('login 3')

    $scope.keypress = (event, auth) ->
      if auth?
        if event.keyCode == 13
            $scope.login(auth)


    $scope.clear = () ->
      $scope.auth = {}
      $scope.auth_error = false
      angular.element('.username').focus()
      return

    return
]
