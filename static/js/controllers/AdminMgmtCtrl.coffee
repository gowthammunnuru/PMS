angular.module("perform").controller "AdminMgmtCtrl", [

  "$scope"
  "$rootScope"
  "$stateParams"
  "allAdmins"
  "allUsers"
  "Auth"
  "Cache"

  ($scope, $rootScope, $stateParams, allAdmins, allUsers, Auth, Cache) ->
    ###
      DDU Employees : o(organization)= "DreamWorks Animation International Services, Inc"
                      Active: true
                      physicalDeliveryOfficeName: !(CHINA-OFFSITE)
      DWA Employees :  o = "DreamWorks Animation L.L.C. "
                      Active: true
    ###
    roles=[]
    roles=[
      {
        'name':'Master_Tigress'
        'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS']
        'assigned':true

      }, {
        'name':'Master_Shifu'
        'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS', 'EDIT_HR']
        'assigned':false

      }, {
        'name':'Master_Oogway'
        'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS', 'SETUP_ROLES', 'EDIT_HR']
        'assigned':false

      }
    ]
    $scope.roles= roles
    $scope.allAdmins = allAdmins
    $scope.allUsers = allUsers
    $scope.viewAdmins = true
    $scope.editAdmins = false
    $scope.toggleViews = (value)->
      if value== 'view'
        $scope.viewAdmins = true
        $scope.editAdmins = false
      else
        $scope.viewAdmins = false
        $scope.editAdmins = true

    $scope.removeRole = (record, role)->

      a = _.findWhere(record.rolesToAssign, name: role)
      a['assigned'] = !a.assigned
      console.log(record.rolesToAssign)
      if(!$scope.$$phase)
        $scope.$apply()

    $scope.removeAdmin = (record) ->
        Cache.removeAdmin(record).then((response)->
          allAdmins.splice(allAdmins.indexOf(record), 1)
        )

    appendCorrectRolesAndPermissions = (record)->
      record.permissions = _.uniq(_.flatten(_.pluck(record.rolesToAssign, 'permissions')))
      record.roles = _.pluck(record.rolesToAssign, 'name')
      return record

    $scope.addAdmin= (record)->
     record.rolesToAssign=_.filter record.rolesToAssign, (a)-> a.assigned
     Cache.addAdmin(appendCorrectRolesAndPermissions(record)).then((response) ->
        $scope.showSuccess = true
        if _.isEmpty(_.findWhere(allAdmins, {'uid':record.uid}))
          allAdmins.push(record)
        else
          allAdmins[allAdmins.indexOf(_.findWhere(allAdmins, {
            'uid': record.uid
          }))] = record

     )

    $scope.closeAlert = (index) ->
      $scope.showSuccess = false

    console.log $scope.allUsers


    $scope.usersByLocation = _.filter($scope.allUsers, (user)->
      user.rolesToAssign =[
        {
          'name':'Master_Tigress'
          'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS']
          'assigned':true

        }, {
          'name':'Master_Shifu'
          'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS', 'EDIT_HR']
          'assigned':false

        }, {
          'name':'Master_Oogway'
          'permissions':['SETUP_REVIEWS', 'EDIT_REVIEWS', 'SETUP_ROLES', 'EDIT_HR']
          'assigned':false

        }
      ]
      user.uname = user.givenName + " " + user.surname
      return (user.active && user.organization == Auth.getUser().organization && user.location.id.indexOf('china-offsite') == -1 )
    )









]