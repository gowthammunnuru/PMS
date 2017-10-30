angular.module("perform").service "Colors", [

  () ->

    @colorScheme  =

      # http://www.google.com/design/spec/style/color.html#color-ui-color-palette
      #             [500 | 900 | 400 | 200 | 600 | 800]

      invisilbe  : ['rgba(0,0,0,0)', 'rgba(0,0,0,0)', 'rgba(0,0,0,0)', 'rgba(0,0,0,0)']
      gray       : ['#9e9e9e', '#212121', '#bdbdbd', '#eeeeee', '#757575', '#046500']
      red        : ['#F44336', '#B71C1C', '#EF5350', '#EF9A9A', '#E53935', '#c62828']
      deeporange : ['#ff5722', '#bf360c', '#ff7043', '#ffab91', '#F4511E', '#D84315']
      orange     : ['#ff9800', '#e65100', '#ffa726', '#ffcc80', '#FB8C00', '#EF6C00']
      amber      : ['#ffc107', '#ff6f00', '#ffca28', '#ffe082', '#FFB300', '#FF8F00']
      purple     : ['#9c27b0', '#4a148c', '#ab47bc', '#ce93d8', '#8E24AA', '#6A1B9A']
      blue       : ['#2196F3', '#0D47A1', '#42A5F5', '#90CAF9', '#1E88E5', '#1565C0']
      lime       : ['#cddc39', '#827717', '#d4e157', '#e6ee9c', '#C0CA33', '#9E9D24']
      teal       : ['#009688', '#004d40', '#26a69a', '#80cbc4', '#00897B', '#00695C']
      green      : ['#4CAF50', '#1B5E20', '#66BB6A', '#A5D6A7', '#43A047', '#00695C']
      darkgreen  : ['#056F00', '#023A00', '#2A8426', '#82B780', '#046500', ''] # Custom - http://knizia.biz/mcg/
      lightgreen : ['#8bc34a', '#33691e', '#9ccc65', '#c5e1a5', '#7CB342', '#4CAF50']
      yellow     : ['#ffeb3b', '#f57f17', '#ffee58', '#fff59d', '#FDD835', '#F9A825']
      brown      : ['#795548', '#3e2723', '#8d6e63', '#bcaaa4', '#6D4C41', '#4E342E']
      bluegrey   : ['#607d8b', '#263238', '#78909c', '#b0bec5', '#546E7A', '#37474F']


    palettes =

      winter: [
          '#FFCDD2'
          '#F8BBD0'
          '#E1BEE7'
          '#D1C4E9'
          '#C5CAE9'
          '#BBDEFB'
          '#B3E5FC'
          '#B2EBF2'
          '#B2DFDB'
          '#C8E6C9'
          '#DCEDC8'
          '#F0F4C3'
          '#FFF9C4'
          '#FFECB3'
          '#FFE0B2'
          '#FFCCBC'
          '#D7CCC8'
          '#F5F5F5'
          '#CFD8DC'
      ]

      poppyColors: [

        "#e91e63", #0
        "#9c27b0", #1
        "#00bcd4", #2
        "#8bc34a", #3
        "#ffeb3b", #4
        "#ffc107", #5
        "#ff9800", #6
        "#ff5722", #7
      ]

    pics = [
      'static/media/peng/mp1.jpg'
      'static/media/peng/mp2.jpg'
      'static/media/peng/mp3.jpg'
      'static/media/peng/mp4.jpg'
    ]

    @random = (colors) -> colors[Math.floor(Math.random() * colors.length)]

    @winterPalette = () -> @random(palettes.winter)

    @profilePic = () -> @random(pics)

    @color = () ->
      @random(palettes.poppyColors)

    return
]
