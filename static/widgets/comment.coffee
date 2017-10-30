"use strict"

angular.module("perform").directive "comment", [

  "Reviews", "Auth"

  (Reviews, Auth) ->

    return {
      restrict: 'E'
      transclude: true
      scope: true

      templateUrl: (element, attrs) ->
        # attrs.mode can be undefined, "multi" or "preview"
        if attrs.mode
          return "static/widgets/comment.#{attrs.mode}.html"
        else
          return "static/widgets/comment.html"

      compile: (element, attrs) ->

        pre: (scope, element, attrs, controller, transclude) ->
          transclude scope, (items) ->
            scope.prompt = items.text()

          return

        post: (scope, element, attrs) ->
          if attrs.mode == 'multi' and not scope.user
            # This will ensure the prompt-multi.html will render just the headings.
            scope.mode = 'headings_only'
          else
            scope.mode = "prompt"

          scope.sanitize = (string) -> string.replace(/\W+/g, '-').toLowerCase()
          scope.modelkey = (string, namespace = "") -> "#{scope.sanitize(namespace)}::#{scope.sanitize(string)}"

          if scope.mode == "headings_only"
            scope.review = {}
          else
            if scope.review_type in ["weights-performance", "weights-potential"]
              uid = scope.template_id
            else
              uid = scope.user.uid

            scope.reviewDetails = Reviews.getReviewPacketByUserAndYear(uid, scope.review_year, scope.review_name, scope.review_type)
            scope.review=scope.reviewDetails.review_body
            if scope.reviewDetails.uid != Auth.getUser().uid && scope.review_type =='self-review'
              scope.notEditable= true

          scope.shouldHighlight = (modelkey) -> modelkey in scope.missingModelKeys

          scope.markdownHelp = [
              title: 'Headings'
              content: """
                       # Heading 1
                       ## Heading 2
                       ### Heading 3
                       #### Heading 4
                       ##### Heading 5
                       ###### Heading 6
                       """
              id: 'headings'
            ,
              title: 'Paragraphs'
              content: """
                       One or more consecutive lines of text
                       separated by one or more blank lines.

                       This is another paragraph.
                       """
              id: 'paragraphs'
            ,
              title: 'Unordered Lists'
              content: """
                       * Red
                       * Green
                         * Light Green
                       * Blue

                       ---

                       - Red
                       - Green
                         - Light Green
                       - Blue
                       """
              id: 'unordered'
            ,
              title: 'Ordered Lists'
              content: """
                       1. Bird
                       2. McHale
                       3. Parish
                       """
              id: 'ordered'
            ,
              title: 'Bold'
              content: """
                       I am **bold**

                       I am __bold too__
                       """
              id: 'bold'
            ,
              title: 'Italic'
              content: """
                       I am in *italics*

                       yup _same deal here_
                       """
              id: 'italic'
            ]
          return
    }
]
