// Generated by CoffeeScript 1.8.0
angular.module("perform").controller("LoginCtrl", [
  "$scope", "Auth", "Portal", "$state", "$stateParams", "$location", function($scope, Auth, Portal, $state, $stateParams, $location) {
    // console.log('Login Ctrl');
    $scope.init = function() {
      return $location.url($state.current.url.split('?')[0]);
    };
    if ($stateParams.auth_error !== "401" && !Auth.getStatus()) {
      $scope.init();
    } else if (Auth.getStatus()) {
      $state.transitionTo('landing.home');
    }
    $scope.auth = {user:''} ;
    $scope.$watch('$stateParams.auth_error', function(newValue, oldValue) {
      return $scope.auth_error = newValue;
    });
    $scope.login = function(auth) {
      console.log('in login')      
      return Auth.login(auth).then(function(response) {
        var stateName, stateParams;
        console.log('Auth Status', Auth.getStatus(), Auth.rejectState);
        if ((Auth.getStatus()) && Auth.rejectState.length) {
          console.log('login 1');
          stateName = Auth.rejectState[0].name;
          if (stateName === 'landing') {
            stateName = 'landing.home';
          }
          stateParams = Auth.rejectState[1];
          Auth.rejectState = [];
          console.log("Recovering", stateName, stateParams);
          return $state.go(stateName, stateParams);
        } else if (Auth.getStatus()) {
          console.log('login 2');
          return $state.go('landing.home');
        } else {
          $scope.auth_error = true;
          console.log('XXXXXXXXXXXXXXX FIX ME XXXXXXXXXXXXXXX');
        }
      });
    };
    $scope.keypress = function(event, auth) {
      console.log('key press')
      if (auth != null) {
        if (event.keyCode === 13) {
          return $scope.login(auth);
        }
      }
    };
    $scope.clear = function() {
      $scope.auth = {};
      $scope.auth_error = false;
      angular.element('.username').focus();
    };
    $scope.keychange = function(){
      console.log('coming here')      
      // Portal.getEmpID($scope.auth.user).then(function(resp){
      //   $scope.empNumber = resp;
        //$scope.user1 = $scope.auth.user;
      // });      
    }
  }
]);
