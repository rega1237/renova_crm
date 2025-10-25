# frozen_string_literal: true

require "caxlsx"

class ClientsExportService
  # Genera un archivo XLSX con los datos de clientes según el scope/consulta proporcionado.
  # Usa find_each para eficiencia con grandes volúmenes.
  # Retorna los bytes del archivo (.xlsx) como String.
  def call(scope)
    package = Axlsx::Package.new
    workbook = package.workbook

    styles = workbook.styles
    header_style = styles.add_style(b: true, alignment: { horizontal: :center }, bg_color: "EFEFEF")
    date_style = styles.add_style(format_code: "yyyy-mm-dd hh:mm")

    workbook.add_worksheet(name: "Clientes") do |sheet|
      # Encabezados descriptivos
      headers = [
        "Nombre",
        "Teléfono",
        "Email",
        "Dirección",
        "CP",
        "Estado",
        "Status",
        "Fuente",
        "Vendedor Prospectación",
        "Vendedor Asignado",
        "Razones",
        "Creado el",
        "Actualizado status el"
      ]
      sheet.add_row(headers, style: header_style)

      helpers = ApplicationController.helpers

      scope.find_each(batch_size: 1000) do |client|
        state_name = client.state&.name
        status_name = helpers.status_display_name(client.status)
        source_name = if helpers.respond_to?(:source_display_name)
          helpers.source_display_name(client.source)
        else
          client.source.to_s.humanize
        end

        seller_prospect = client.prospecting_seller&.name
        seller_assigned = client.assigned_seller&.name

        row = [
          client.name,
          client.phone,
          client.email,
          client.address,
          client.zip_code,
          state_name,
          status_name,
          source_name,
          seller_prospect,
          seller_assigned,
          client.reasons,
          client.created_at,
          client.updated_status_at
        ]

        # Aplicar estilo de fecha a las últimas dos columnas
        styles_for_row = Array.new(headers.length)
        styles_for_row[-2] = date_style
        styles_for_row[-1] = date_style

        sheet.add_row(row, style: styles_for_row)
      end

      # Opcional: auto-filtros y ancho de columnas
      sheet.auto_filter = "A1:M1"
      sheet.column_widths 22, 15, 24, 28, 10, 18, 22, 16, 26, 24, 30, 18, 24
    end

    package.to_stream.read
  end
end