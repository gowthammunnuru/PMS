angular.module("perform").filter "AddedReviewersFilter", [->
  (input, current_reviewers_uid, map) ->

    i = undefined

    return input  if current_reviewers_uid is `undefined`

    (item for item in input when current_reviewers_uid.indexOf(map[item]) == -1)
]
