// Generated by CoffeeScript 1.8.0
angular.module("perform").controller("AuthErrorCtrl", [
  "$scope", "$stateParams", "$state", function($scope, $stateParams, $state) {
    $scope.url = $state.href($state.current.data.rejectState, $state.current.data.rejectParams);
    $scope.image = "/static/media/autherror/autherror-" + (Math.floor(Math.random() * 4) + 1) + ".jpg";
  }
]);