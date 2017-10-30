angular.module("perform").controller "SetupTemplatesCtrl", [

  "$scope"
  "$state"
  "$stateParams"
  "WS"
  "Utils"
  "$location"
  "allUsers"
  "allTemplates"
  "allReviews"

  ($scope, $state, $stateParams, WS, Utils, $location, allUsers, allTemplates, allReviews) ->

    $scope.review_year = $stateParams.review_year
    $scope.review_name = $stateParams.review_name

    $scope.allTemplates = allTemplates

    $scope.setupAndPreview = (template) ->
      '''
      This method is copy/paste to js/controllers/9BoxCtrl.coffee
      '''

      # If the template weights have not been setup (initialized), then do it
      if template['weights-performance'].error or template['weights-potential'].error
        WS.setTemplateWeights(template.id, $scope.review_year, $scope.review_name).then (response) =>

          $state.go 'admin.templates.preview_template.render',
            review_year: $scope.review_year
            review_name: $scope.review_name
            template_id: template.template_id
      else
        # If its already initialized, just go there.
        $state.go 'admin.templates.preview_template.render',
          review_year: $scope.review_year
          review_name: $scope.review_name
          template_id: template.template_id

    return
]
