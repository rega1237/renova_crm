module CalendarHelper
  def color_for_seller(seller)
    return '#808080' unless seller # Color gris para citas sin vendedor

    # Paleta de 20 colores distintos
    colors = [
      '#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf',
      '#aec7e8', '#ffbb78', '#98df8a', '#ff9896', '#c5b0d5', '#c49c94', '#f7b6d2', '#c7c7c7', '#dbdb8d', '#9edae5'
    ]

    index = seller.id.hash.abs % colors.length
    colors[index]
  end
end
