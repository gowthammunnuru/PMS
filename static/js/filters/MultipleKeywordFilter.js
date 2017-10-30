// Generated by CoffeeScript 1.10.0
angular.module("perform").filter("MultipleKeywordFilter", [
  "$filter", function($filter) {
    return function(input, searchText) {
      var filteredList, i, len, searchKey, searchList, searchTextSplit;
      filteredList = [];
      if (angular.isUndefined(searchText)) {
        return input;
      }
      searchTextSplit = searchText.$.split(' ');
      searchList = _.each(input, function(item) {
        return delete item['review_body'];
      });
      for (i = 0, len = searchTextSplit.length; i < len; i++) {
        searchKey = searchTextSplit[i];
        filteredList = $filter("filter")(searchList, searchKey);
        searchList = filteredList;
      }
      return filteredList;
    };
  }
]);