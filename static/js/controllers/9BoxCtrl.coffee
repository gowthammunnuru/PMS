angular.module("perform").controller "9BoxCtrl", [


  "$scope"
  "$rootScope"
  "$stateParams"
  "Reviews"
  "BG"
  "Utils"
  "WS"
  "userinfo"
  "users"
  "$state"
  "$interval"
  "NineBox"
  "Cache"
  "reviews"
  "selfReviews"
  "template"


  ($scope, $rootScope, $stateParams, Reviews, BG, Utils, WS, userinfo, users, $state, $interval, NineBox, Cache, reviews, selfReviews, template) ->

    templates = (review?.latest_template for review in reviews)

    $scope.review_year   = $stateParams.review_year
    $scope.review_name   = $stateParams.review_name

    $scope.review_type   = $state.current.data.review_type

    $scope.template    = template
    $scope.template_id = $scope.template.template_id # pick the first one.

    # Check if all folks have the same template
    sameTemplate = templates.every (t) -> t.template_id == templates[0].template_id

    if not sameTemplate
      console.log('Not same template. Error (404)')
      $state.go('404') # TODO: Make this better

    $scope.reviews     = (Reviews.getset(x.latest_review, $scope.review_type) for x in reviews)
    $scope.selfReviews = selfReviews

    $scope.users   = users

    $scope.sectionName = $stateParams.section

    $scope.enableAutoUpdate = () ->
      Reviews.autoUpdate()

    $scope.$on '$destroy', () ->

      for own uid, review of $scope.reviews
        Reviews.remove(review, $scope.review_type)

      Reviews.stopAutoUpdate()


    noOfUsers =  $scope.users.length

    if noOfUsers < 30
      freq = null  # default
    else
      freq = 6

    Reviews.autoUpdate(resetKillSwitch = true, freq = freq)

    $scope.setupAndPreview = (template) ->
      '''
      copy/pasted from js/controllers/SetupTemplatesCtrl.coffee
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
