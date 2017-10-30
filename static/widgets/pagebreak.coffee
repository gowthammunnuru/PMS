"use strict"

angular.module("perform").directive "pagebreak", [
  () ->
    restrict: 'E'
    replace: true
#    template: '<div style="page-break-after:always; page-break-inside:avoid;"></div>'
#    template: '<p>&nbsp;</p>'
    template: '<div class="pagebreak">pagebreak&nbsp</div>'
]
