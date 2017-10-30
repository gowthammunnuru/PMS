angular.module("perform").controller "DialogAcknowledgeCtrl", [
  "$scope"
  "$modal"
  "$modalInstance"

  ($scope, $modal, $modalInstance) ->

    $scope.ok = () -> $modalInstance.close()

    $scope.cancel = () -> $modalInstance.dismiss()

    return
]
