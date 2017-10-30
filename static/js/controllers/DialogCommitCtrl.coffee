angular.module("perform").controller "DialogCommitCtrl", [
  "$scope"
  "$modal"
  "$modalInstance"
  "messages"

  ($scope, $modal, $modalInstance, messages) ->


    $scope.messages = messages

    $scope.currModelKeys = $scope.messages.getCurrModelKeys()
    $scope.modelkeys     = $scope.messages.modelkeys

    $scope.missingModelKeys = _.difference($scope.modelkeys, $scope.currModelKeys)

    $scope.completedPercent = _.min([($scope.currModelKeys.length * 100 / $scope.modelkeys.length).toFixed(), 100])

    $scope.icons =
      0: 'lock'
      1: 'warning-sign'

    $scope.ok = () -> $modalInstance.close()

    $scope.cancel = () -> $modalInstance.dismiss

      all     : $scope.modelkeys
      curr    : $scope.currModelKeys
      missing : $scope.missingModelKeys

    $scope.extra_confirmation = ''

    return
]
