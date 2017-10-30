angular.module("perform").filter "MultipleKeywordFilter", [
  "$filter"

  ($filter) ->
    (input, searchText) ->

      filteredList = []

      if angular.isUndefined(searchText)
        return input

      searchTextSplit = searchText.$.split(' ')
      searchList = _.each(input, (item) ->
        delete item['review_body']
      )

      for searchKey in searchTextSplit
        filteredList = $filter("filter") searchList, searchKey
        searchList = filteredList

      return filteredList
]
