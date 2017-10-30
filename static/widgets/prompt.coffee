"use strict"

angular.module("perform").directive "prompt", [

  "Colors"
  "Reviews"
  "Auth"

  (Colors, Reviews, Auth) ->
    restrict: "E"
    transclude: true
    scope: true
    templateUrl:  (element, attrs) ->
      # attrs.mode can be undefined, "multi" or "preview"
      if attrs.mode
        return "static/widgets/prompt.#{attrs.mode}.html"
      else
        return "static/widgets/prompt.html"

    compile: (element, attrs) ->

      pre: (scope, element, attrs, controller, transclude) ->
        transclude scope, (items) ->

          attrs.criteria = (name: x.innerHTML, desc: x.getAttribute('desc') for x in items when x.innerHTML)

      post: (scope, element, attrs) ->

        scope.headings = [

          name: 'Too new / NA'
          pts: 0
          name_alt: "NA"
          desc: "Unable to evaluate at this time; new to the position or has not received the opportunity for exhibiting the skill yet."
        ,
          name: 'Imp needed'
          pts: 1
          name_alt: "Not important at all"
          desc: "Consistently does not meet expectations. Needs significant improvement in critical areas of expected job results or competencies."
        ,
          name: 'Inconsistent'
          pts: 2
          name_alt: "Not particularly important"
          desc: "Occasionally meets expectations; however, work quality/quantity does not consistently meet requirements of the job."
        ,
          name: 'Developing'
          pts: 3
          name_alt: "Somewhat important"
          desc: "Consistently meets expectations. However skill not fully developed; showing a steady progression in skill set; learning a new skill or department."
        ,
          name: 'Achieves'
          pts: 4
          name_alt: "Important"
          desc: "Consistently meets expectations."
        ,
          name: 'Achieves+'
          pts: 5
          name_alt: "Very important"
          desc: "Consistently meets expectations and occasionally exceeds expectations."
        ,
          name: 'Exceeds'
          pts: 6
          name_alt: "Must have"
          desc: "Consistently exceeds expectations and demonstrates role model behaviors."
        ]

        scope.headings_weights = [

          name: 'NA'
          pts: 0
        ,
          name: "Not particularly important"
          pts: 1
        ,
          name: 'Somewhat important'
          pts: 2
        ,
          name: 'Important'
          pts: 3
        ,
          name: 'Very important'
          pts: 4
        ,
          name: 'Must have'
          pts: 5
        ]

        scope.getHeading = (pts) -> (x for x in scope.headings when x.pts == pts)[0]

        scope.blocktitle =  attrs.blocktitle
        scope.collapse =
          icons: ['glyphicon-plus', '']
          state: true


        scope.bg           = (color = Colors.colorScheme.invisilbe) -> 'background-color': color[0], 'border-color': color[0]
        scope.overlayColor = (color = Colors.colorScheme.invisilbe) -> 'background-color': "#{color[0]}"


        scope.palette =

          colors: [
            scope.bg(Colors.colorScheme.gray)
            scope.bg(Colors.colorScheme.amber)
            scope.bg(Colors.colorScheme.lime)
            scope.bg(Colors.colorScheme.lightgreen)
            scope.bg(Colors.colorScheme.green)
            scope.bg(Colors.colorScheme.darkgreen)
            scope.bg(Colors.colorScheme.bluegrey)
          ]

          selfReviewColors: [

            scope.overlayColor(Colors.colorScheme.gray)
            scope.overlayColor(Colors.colorScheme.amber)
            scope.overlayColor(Colors.colorScheme.lime)
            scope.overlayColor(Colors.colorScheme.lightgreen)
            scope.overlayColor(Colors.colorScheme.green)
            scope.overlayColor(Colors.colorScheme.darkgreen)
            scope.overlayColor(Colors.colorScheme.bluegrey)
          ]

        if attrs.mode == 'multi' and not scope.user
          # This will ensure the prompt-multi.html will render just the headings.
          scope.mode = 'headings_only'
        else
          scope.mode = "prompt"

        scope.sanitize = (string) -> string.replace(/\W+/g, '-').toLowerCase()
        scope.modelkey = (string, namespace="") -> "#{scope.sanitize(namespace)}::#{scope.sanitize(string)}"


        scope.resetRating = () -> (scope.bg() for x in scope.headings)

        if scope.mode == "headings_only"
          scope.review = {}
        else

          if scope.review_type in ["weights-performance", "weights-potential"]
            uid = scope.template_id
          else
            uid = scope.user.uid

          scope.latest_review = Reviews.getReviewPacketByUserAndYear(uid, scope.review_year, scope.review_name, scope.review_type)
          

          scope.review        = scope.latest_review?.review_body
          if scope.latest_review.uid!= Auth.getUser().uid && scope.review_type =='self-review'
            scope.notEditable= true

        scope.criteria =
          for criterion in attrs.criteria
            name: criterion.name
            desc: criterion.desc
            colors: scope.resetRating()
            selfReviewColors: scope.resetRating()
            value: scope.review[scope.modelkey(criterion.name, "ratings::#{scope.blocktitle}")]
            modelkey: scope.modelkey(criterion.name, "ratings::#{scope.blocktitle}")

        if scope.mode == "headings_only"
          return

        scope.setColorRating = (criterion, index, barType = 'colors') ->
          '''
          barType is either 'colors'  or 'selfReviewColors'
            colors        : proper review
            selfReviewColors : self-review
          '''

          # The index is used to show/hide the floating-label.
          if barType is 'colors'
            criterion.colorIndex = index
          else if barType is 'selfReviewColors'
            criterion.selfReviewIndex = index

          for i in [0...scope.headings.length]
            if i <= index
              criterion[barType][i] = scope.palette[barType][index]
            else
              criterion[barType][i] = if barType is 'color' then scope.bg() else scope.overlayColor()

        scope.update = (review, barType) ->

          if not review
            return


          for criterion in scope.criteria
            scope.setColorRating(criterion, parseInt(review[scope.modelkey(criterion.name, "ratings::#{scope.blocktitle}")]), barType)

          if scope.review_type in ["weights-performance", "weights-potential"]
            uid = scope.template_id
          else
            uid = scope.user.uid

          scope.latest_review = Reviews.getReviewPacketByUserAndYear(uid, scope.review_year, scope.review_name, scope.review_type)

        scope.$watch 'review', (newValue, oldValue) ->
          scope.update(scope.review, 'colors')
        , true

        scope.$watch 'selfReview', (newValue, oldValue) ->
          if scope.selfReview
            scope.update(scope.selfReview.review_body, 'selfReviewColors')
        , true

        scope.$watch 'latest_review', (newValue, oldValue) ->

          scope.review_locked = scope.latest_review.locked || scope.latest_review.committed

        , true

        scope.mouseover = ($event, index, criterion, item) ->

          scope.setColorRating(criterion, index)

        scope.mouseout = ($event, index, criterion, item) ->

          scope.setColorRating(criterion, parseInt(scope.review[scope.modelkey(criterion.name, "ratings::#{scope.blocktitle}")]))

        scope.setRating = (criterion, index, heading) ->

          scope.review[scope.modelkey(criterion.name, "ratings::#{scope.blocktitle}")] = heading.pts
          scope.setColorRating(criterion, index)

          return

        scope.shouldHighlight = (modelkey) -> modelkey in scope.missingModelKeys

        return
]
